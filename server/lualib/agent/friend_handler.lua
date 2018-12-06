local skynet = require "skynet"
-- local sharedata = require "sharedata"
-- local sharedata = require "skynet.sharedata"

local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"
local constant = require "constant"

local dump = require "common.dump"
local RPC = {}
local CMD = {}
handler = handler.new (RPC, CMD)

local user
local database
local friendserver
local friends
local commend_friends


handler:init (function (u)
	user = u
    database = skynet.queryservice ("database")
	friendserver = skynet.queryservice ("friend_server")
end)

handler:login_init (function ()
    friends = skynet.call(friendserver, "lua", "get_change_friends",user.character) or {}
    user.send_request('sync_friend_list', {friend_list=friends})
end)

local function save_db( friend_info )
    skynet.call(database, "lua", "friend", "saveFriend", user.character.id, friend_info)
end

local function del_db( friend_id )
    skynet.call(database, "lua", "friend", "delFriend", user.character.id, friend_id)    
end

local function update_db( friend_info )
    skynet.call(database, "lua", "friend", "updateFriend", user.character.id, friend_info )        
end

local function find_friend( role_id )
    if not role_id then return end
    if next(friends) == nil then return end

    for k ,v in pairs(friends) do
        if v.role_info.role_id == role_id then
            return k ,v
        end
    end
end

local function add_friend_info( add_info )
    local index = find_friend(add_info.role_info.role_id)
    if index then 
        friends[index] = add_info
    else
        table.insert( friends, add_info)
    end
    update_db( add_info )
end

function RPC.rpc_apply_add_friend (args)
    if #friends >= 200 then
        syslog.warn("rpc_apply_add_friend friends too mony: ",user.account)
        return
    end
    local be_apply_id = args and args.be_apply_id
    if not be_apply_id then
        syslog.warn("rpc_apply_add_friend param error role: ",user.account)
        return
    end
    if be_apply_id == user.account then
        syslog.warn("rpc_apply_add_friend not add self : ",user.account)
        return
    end
    local target_info = skynet.call(friendserver,"lua","get_online_role_info",be_apply_id) 
    if not target_info then
        user.send_request( "send_error_id", {error_id=constant.ROLE_NOT_ONLINE})        
        -- syslog.warn("rpc_apply_add_friend role not exist or not online: ",user.account)
        return
    end
    
    local index,friend_info  = find_friend(be_apply_id)
    local nowtime = math.floor (skynet.time())
    if friend_info then
        if friend_info.flag == constant.FlagOK then
            syslog.warn("rpc_apply_add_friend role already isfriend : ",user.account)
            return
        elseif nowtime < friend_info.time + 10 then    --todo...  gameconfig 
            syslog.warn("rpc_apply_add_friend at cd : ",user.account)
            return
        end
    end

    friend_info = {
        role_info = {
            role_id = be_apply_id,
            nickname = target_info.general.nickname,
            race = target_info.general.race,
            level = target_info.attribute.level,
        },
        flag = constant.FlagApplying,
        time = nowtime,
        online = constant.FlagOnline,
    }
    local apply_info = {
        role_info = {
            role_id = user.account,
            nickname = user.character.general.nickname,
	        race = user.character.general.race,
	        level = user.character.attribute.level,
        },
        flag = constant.FlagBeApply, 
        time = nowtime,
        online = constant.FlagOnline,
    }
    skynet.call(friendserver, "lua", "cmd_send_add_apply", apply_info, be_apply_id)
    add_friend_info(friend_info)
    return { friend_info = friend_info }
end

function RPC.rpc_confirm_add_friend (args)
    if #friends >= 200 then
        syslog.warn("rpc_confirm_add_friend friends too mony: ",user.account)
        return
    end
    local friend_id = args and args.friend_id
    if not friend_id then
        syslog.warn("rpc_confirm_add_friend param error account: ",user.account)
        return
    end
    local flag = args.flag
    if not flag or (flag ~= constant.FlagAccept and flag ~= constant.FlagReject) then
        syslog.warn("rpc_confirm_add_friend flag error :",user.account,flag)
        return
    end
    local is_online = skynet.call(friendserver, "lua", "check_online", user.account) 
    if not is_online then
        syslog.warn("rpc_confirm_add_friend self not online: ",user.account)
        return
    end
    local index,apply_info = find_friend(friend_id)
    if not apply_info then 
        syslog.warn("rpc_confirm_add_friend apply_info not exist :",user.account)
        return
    end
    if apply_info["flag"] ~= constant.FlagBeApply then
        syslog.warn("rpc_confirm_add_friend apply error : ",user.account,apply_info["flag"])
        return
    end
    if flag == constant.FlagAccept then
        flag = constant.FlagOK
    end
    local friend_info = friends[index]
    local  nowtime = math.floor (skynet.time())
    friend_info.flag = flag
    friend_info.time = nowtime
    skynet.call(friendserver, "lua", "addConfirm", user.character, friend_id, flag ,nowtime)
    update_db( friend_info )
    return {friend_info = friend_info}
end

function RPC.refresh_friend_info( args )
    local friend_id = args and args.friend_id
    if not friend_id then 
        syslog.warn("refresh_friend_info param error :",user.account,friend_id)
        return
    end

    local index,friend_info = find_friend(friend_id)
    if not friend_info or friend_info.flag ~= constant.FlagOK then 
        syslog.warn("refresh_friend_info not friend: ",user.account,friend_id)
        return
    end

    local nowtime = math.floor (skynet.time())
    if nowtime < friend_info.time + 2 then 
        syslog.warn("refresh_friend_info too fast")
        return
    end

    local friend = skynet.call(friendserver,"lua","get_online_role_info",friend_id) 
    if not friend then 
        syslog.warn("refresh_friend_info friend not online")
        return
    end

    friend_info.role_info.nickname = friend.general.nickname
    friend_info.role_info.race = friend.general.race
    friend_info.role_info.level = friend.attribute.level
    friend_info.time = nowtime
    
    friends[index] = friend_info
    return { friend_info = friend_info }
end

function RPC.get_commend_friend( args )
    commend_friends = commend_friends
    if not commend_friends or args.is_refresh or not next(commend_friends) then
        commend_friends = skynet.call( friendserver , "lua", "get_commend_friend" , user.account ,friends ) 
    else
        for k,v in pairs( commend_friends ) do
            local online = skynet.call(friendserver, "lua", "check_online", v.role_info.role_id )
            v.online = online and constant.FlagOnline or constant.FlagOffline
        end
    end
    return { commend_friends = commend_friends }
end

function RPC.rpc_del_friend( args )
    local remove_id = args and args.remove_id
    if not remove_id then 
        syslog.warn("rpc_del_friend param error :",user.account)
        return
    end
    local index,friend_info = find_friend(remove_id)
    if not index then 
        syslog.warn("rpc_del_friend remove_id error :",user.account,remove_id)
        return 
    end
    if friend_info.flag == constant.FlagOK then
        skynet.call( friendserver, "lua", "del_friend" , remove_id, user.account )
    end
    table.remove( friends, index )
    del_db( remove_id )
    return { remove_id = remove_id }
end

function CMD.del_friend( remove_id )
    local index = find_friend(remove_id)
    if not index then return end
    table.remove( friends, index )
    del_db( remove_id )
    user.send_request( "send_del_friend" , {friend_id = remove_id} )
end

function CMD.get_friends()
    return friends
end

function CMD.friend_add( add_info )
    user.send_request("rpc_send_friend_info",{friend_info = add_info})
end

function CMD.check_friends( target_id )
    local _ , friend_info = find_friend(target_id)
    if friend_info and friend_info.flag == constant.FlagOK then
        return true
    end
end

function CMD.add_friend_response( friend_info )
    add_friend_info(friend_info)
    user.send_request("rpc_send_friend_info",{ friend_info = friend_info })
end

function CMD.add_friend_apply_info( add_info )
    add_friend_info(add_info)
    user.send_request("rpc_send_friend_info",{ friend_info = add_info })
end

function CMD.friend_change_online_status( role_id ,online )
    local index,friend_info = find_friend(role_id)
    if not index then return end
    friend_info.online = online
    friends[index] = friend_info
    user.send_request("rpc_send_friend_info",{ friend_info = friend_info })
end

--[[
function CMD.cmd_friend_send_msg( _account, _msg )
    -- user.send_request ("labor_send", { msg = _msg }) -- protocol
    local info = skynet.call (database, "lua", "account", "cmd_account_loadInfo", _account)
    if info then
        info = dbpacker.unpack(info)
    end
    user.send_request ("tips", { content = string.format("【%s】 say:%s", info.nickname, _msg) })
end

function CMD.cmd_friend_online_notify( _account )
    local info = skynet.call (database, "lua", "account", "cmd_account_loadInfo", _account)
    if info then
        info = dbpacker.unpack(info)
    end
    user.send_request ("tips", { content = string.format("【%s】 online", info.nickname) })
end
]]

return handler

