local skynet = require "skynet"
local syslog = require "syslog"
local dbpacker = require "db.packer"
local dump = require "common.dump"
local constant = require "constant"

local table = table

local friendTab = {}

local database
local CMD = {}

local function save_give_info( target_id, give_info )
    skynet.call(database, "lua", "friend", "saveGiveInfo", target_id, give_info )
end

local function onlineNotify(account, _func, ...)
    local ok, agent = CMD.check_online(_,account)
    if ok then
        skynet.send(agent, "lua", _func, ...)
    end
end

local function update_db( account , friend_info )
    skynet.call(database, "lua", "friend", "updateFriend", account, friend_info )
end


local function check_can_commend( info, account ,friends )
    if info.online ~= constant.FlagOnline then return end
    if info.account == account then return end
    for _,v in pairs(friends) do
        if v.role_info.role_id == info.account then return end
    end
    return true 
end

local function get_commend_friend_info( agent )
    local info = skynet.call( agent , "lua" , "get_role_info" )
    return {
        role_info = {
            role_id = info.id,
            nickname = info.general.nickname,
            race = info.general.race,
            level = info.attribute.level,
        },
        flag = constant.FlagNone,
        online = constant.FlagOnline,
    }
end

function CMD.get_commend_friend( _ , account ,friends )
    if not next(friendTab) then return end
    local online_role_info = {}
    for k,v in pairs(friendTab) do
        if check_can_commend( v, account ,friends ) then
            table.insert( online_role_info, get_commend_friend_info( v.agent ) )
        end
        if #online_role_info >= 20 then break end
    end
    return online_role_info
end

function CMD.check_online( _ , account)
    local friInfo = friendTab[account]
    if friInfo and friInfo["online"] == constant.FlagOnline then
        return true, friInfo["agent"]
    end
end

function CMD.check_target_exist( _ , account )
    return friendTab[account]  ~= nil
end

function CMD.get_online_role_info( _ , target_id )
    local online,target_agent = CMD.check_online( _, target_id)
    if not target_agent then return end
    return skynet.call( target_agent , "lua" , "get_role_info" )
end

function CMD.cmd_online(source, info)
    local account = info.id
    local friends = info.friends
    assert(friends or account,"-----friends or account is nil")
    for _,v in pairs(friends) do
        -- v = dbpacker.unpack(v)
        onlineNotify(v.role_info.role_id, "friend_change_online_status", account, constant.FlagOnline)
    end
    local friInfo = {
        account = account,
        agent = source,
        online = constant.FlagOnline,
    }
    friendTab[account] = friInfo
end

function CMD.cmd_offline( _ , account, friends)
    local friInfo = friendTab[account]
    assert(friInfo, string.format("Error, not found account:%d", account))
    friInfo["agent"] = nil
    friInfo["online"] = constant.FlagOffline
    
    for _,v in pairs(friends) do
        onlineNotify(v.role_info.role_id, "friend_change_online_status", account, constant.FlagOffline)
    end
end

function CMD.cmd_send_add_apply(source, add_info, target_id)
    local ok,target_agent = CMD.check_online(_,target_id)
    if not ok then return end
    skynet.call( target_agent , "lua" , "add_friend_apply_info" , add_info )
    onlineNotify(target_id, "friend_add", add_info)
end

function CMD.addConfirm(source, user_info, apply_id, flag ,nowtime)
    if flag == constant.FlagReject then 
        flag = constant.FlagBeReject
    end
    local _,agent = CMD.check_online( _, apply_id)

    local friend_info = {
        role_info = {
            role_id = user_info.id,
            nickname = user_info.general.nickname,
            race = user_info.general.race,
            level = user_info.attribute.level,
        },
        flag = flag,
        time = nowtime,
        online = constant.FlagOnline,
    }
    if agent then 
        skynet.call(agent ,"lua", "add_friend_response" , friend_info )
    else
        update_db(apply_id,friend_info)
    end
end

function CMD.del_friend( _ , self_id , target_id )
    local  _ , target_agent = CMD.check_online( _ , self_id )
    if target_agent then
        skynet.call( target_agent , "lua", "del_friend" ,target_id )
    else
        skynet.call(database, "lua", "friend", "delFriend", self_id, target_id)  
    end
end

function CMD.del(source, _srcAcc, _dstAcc)
    local friInfo = friendTab[_srcAcc]
    assert(friInfo, string.format("Error, not found account:%d", _srcAcc))

    local dstInfo = friInfo["friends"][_dstAcc]
    assert(dstInfo, string.format("Error, not found account:%d", _dstAcc))

    local b1 = skynet.call(database, "lua", "friend", "delFreind", _srcAcc, _dstAcc)
    local b2 = skynet.call(database, "lua", "friend", "delFreind", _srcAcc, _dstAcc)
    assert(b1 and b2, "Error, freind del")
end

function CMD.get_change_friends( _ , info )
    assert(info, "Error info is nil")
    local friends = info.friends
    for _,v in pairs(friends) do
        local ok, _ = CMD.check_online(_,v.role_info.role_id)
        v.online = ok and constant.FlagOnline or constant.FlagOffline
    end
    return friends
end


function CMD.give_item2target( _ , target_id, give_info )
    local _ , target_agent = CMD.check_online( _ ,target_id )
    if target_agent then
        skynet.call( target_agent ,"lua", "receive_give_item", give_info)
    else
        save_give_info(target_id, give_info)
    end
end

function CMD.broad(source, _srcAcc, _dstAcc, _msg)
    local function sendMsg( ... )
        onlineNotify(_dstAcc, "friend_sendChat", _srcAcc, _msg)
    end
    skynet.fork(sendMsg)
end

function CMD.open (source, conf)
    syslog.debugf("--- friend server open")
    database = skynet.uniqueservice ("database")
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat friendserver")
end

local traceback = debug.traceback
skynet.start (function ()
    -- skynet.timeout (800, function() skynet.exit() end) -- for test moniter

    skynet.dispatch ("lua", function (_, source, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warnf ("unhandled message(%s)", command)
            return skynet.ret ()
        end


        local function ret (ok, ...)
            if not ok then
                syslog.warnf ("handle message(%s) failed", command)
                skynet.ret ()
            else
                skynet.retpack (...)
            end  
        end
        ret (xpcall (f, traceback , source, ...))
        
        --[[
        local ok, ret = xpcall (f, traceback, source, ...)
        if not ok then
            syslog.warnf ("handle message(%s) failed : %s", command, ret)
            return skynet.ret ()
        end
        skynet.retpack (ret)
        ]]
    end)
end)

--[[
local function saveAddInfo(_srcAcc, _dstAcc, _flag)
    local addInfo = {
        account = _dstAcc,
        flag = _flag,
    }
    local json = dbpacker.pack(addInfo)
    -- skynet.call(database, "lua", "friend", "saveFriend", _srcAcc, _dstAcc, json)
end

function CMD.loadAddInfo( _ , _srcAcc , _dstAcc )
    local json = skynet.call(database, "lua", "friend", "loadFreind", _srcAcc, _dstAcc)
    if json then
        return true, dbpacker.unpack(json)
    end
end
]]
