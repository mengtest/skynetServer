local skynet = require "skynet"
-- local sharedata = require "skynet.sharedata"

local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"
local constant = require "constant"

local helper = require "common.helper"
local dump = require "common.dump"
local RPC = {}
local CMD = {}
handler = handler.new (RPC, CMD)

local user
local database
-- local friendserver
local mailserver
local nameserver

local mails

local MAX_MAIL_COUNT = 80
local MAIL_EXPIRE_TIME = 14*86400

handler:init (function (u)
	user = u
    database = skynet.queryservice ("database")
    -- friendserver = skynet.uniqueservice ("friend_server")
    mailserver = skynet.queryservice ("mail_server")
    nameserver = skynet.queryservice("name_house")
end)

local function find_mail( mail_guid )
    for k,v in pairs(mails) do
        if v.mail_guid == mail_guid then
            return k,v
        end
    end
end

local function del_mail( mail_guid )
    local index = find_mail(mail_guid)
    assert(index,"error  del_mail---mail not exist")
    table.remove( mails, index )
    skynet.call(database, "lua", "mail", "del_mail",user.account, mail_guid)
end

local function del_all_mail()
    mails = {}
    skynet.call(database, "lua", "mail", "del_all_mail", user.account )
end

local function del_expire_mail()
    for _,v in ipairs(mails) do
        if v.time + MAIL_EXPIRE_TIME < math.floor(skynet.time()) then
            del_mail( v.mail_guid )
        end
    end
end

local function check_mail_is_expire( mail_info )  
    if mail_info.time + MAIL_EXPIRE_TIME < math.floor(skynet.time()) then
        return true
    end
end

local function check_mail_count()
    while #mails > MAX_MAIL_COUNT do
        table.remove(mails,1)
    end
end

handler:login_init (function ()
    -- mails = user.character.mails
    -- if next(mails) ~= nil then
    --     del_expire_mail()
    --     check_mail_count()
    --     user.send_request( "sync_mails", {mails = mails} )
    -- end
end)

local function save_mail( mail_info )
    local index = find_mail(mail_info.mail_guid)
    assert(not index,"error save_mail mail already exist" .. mail_info.mail_guid)
    table.insert( mails, mail_info )
    skynet.call(database, "lua", "mail", "save_mail",user.account, mail_info)
end

local function update_mail( mail_info )
    -- local index = find_mail(mail_info.mail_guid)
    -- assert(index,"error update_mail---mail not exist")
    -- mails[index] = mail_info
    skynet.call(database, "lua", "mail", "update_mail",user.account, mail_info)
end

function RPC.get_mail_message( args )
    local mail_guid = args.mail_guid
    if not mail_guid then 
        syslog.warn("get_mail_message param error : ", user.account)
        return
    end
    local _ ,mail_info = find_mail(mail_guid)
    if not mail_info then 
        syslog.warn("get_mail_message mail_guid error : ", user.account)
        return
    end

    if mail_info.status ~= constant.Undisposed then
        syslog.warn("get_mail_message mail status error : ", user.account, mail_info.status)
        return
    end
    mail_info.status = constant.AlreadyRead
    update_mail( mail_info )
    return { mail_guid=mail_guid }
end

function RPC.receive_mail_item( args )
    local mail_guid = args.mail_guid
    if not mail_guid then 
        syslog.warn("receive_mail_item param error : ", user.account)
        return
    end
    local _ ,mail_info = find_mail(mail_guid)
    if not mail_info then 
        syslog.warn("receive_mail_item mail_guid error : ", user.account)
        return
    end
    
    -- if check_mail_is_expire(mail_info) then
    --     syslog.warn("receive_mail_item mail expire : ", user.account,mail_guid)
    --     return
    -- end

    if mail_info.status == constant.AlreadyGet then
        syslog.warn("receive_mail_item mail status error : ", user.account, mail_info.status)
        return
    end
    local item_list = mail_info.item_list
    if not item_list then
        syslog.warn("receive_mail_item mail not item receive : ", user.account)
        return
    end

    mail_info.status = constant.AlreadyGet
    user.CMD.add_item_list(item_list)
    update_mail( mail_info )
    return { mail_guid=mail_guid }
end


function RPC.receive_all_mail_item()
    local mail_guid_list = {}
    for _,v in ipairs(mails) do
        local item_list = v.item_list
        if v.status ~= constant.AlreadyGet and item_list then
            v.status = constant.AlreadyGet
            user.CMD.add_item_list(item_list)
            update_mail( v )
            mail_guid_list[#mail_guid_list+1] = v.mail_guid
        end
    end
    return { mail_guid_list=mail_guid_list }
end


function RPC.del_mail( args )
    local mail_guid = args.mail_guid
    if not mail_guid then 
        syslog.warn("del_mail param error : ", user.account)
        return
    end
    local _ ,mail_info = find_mail(mail_guid)
    if not mail_info then 
        syslog.warn("del_mail mail_guid error : ", user.account)
        return
    end
    if mail_info.status == constant.Undisposed then
        syslog.warn("del_mail mail status error : ", user.account, mail_info.status)
        return
    end
    del_mail( mail_guid )
    return { mail_guid=mail_guid }
end

function RPC.del_all_mail()
    local del_mail_guid_list = {}
    for _,v in ipairs(mails) do
        local item_list = v.item_list
        local mail_status = v.status
        if mail_status == constant.AlreadyGet or (mail_status == constant.AlreadyRead and not item_list) then
            del_mail_guid_list[#del_mail_guid_list+1] = v.mail_guid
        end
    end

    for _,v in ipairs(del_mail_guid_list) do
        del_mail(v)
    end

    return { del_mail_guid_list=del_mail_guid_list }
end

function CMD.receive_mail( mail_info )
    save_mail( mail_info )
    -- del_expire_mail()
    user.send_request("sync_new_mail", {mail_info = mail_info} )
end

function RPC.role_send_mail( args )
    -- local target_name = args.target_name
    -- local title = args.title
    -- local content = args.content

    -- local item_list = args.item_list
    -- if not target_name or not title or not content then 
    --     syslog.warnf("role_send_mail param error :",user.account)
    --     return 
    -- end

    -- local title_len = helper.get_string_len( title )
    -- if title_len <= 0 or title_len > 10 then  --todo... gameConfig
    --     syslog.warn("role_send_mail title len illegal: ".. user.account)
    --     return
    -- end

    -- local content_len = helper.get_string_len( content )
    -- if content_len <= 0 or content_len > 40 then  --todo... gameConfig
    --     syslog.warn("role_send_mail content len illegal: ".. user.account)
    --     return
    -- end

    -- local target_id = skynet.call( nameserver, "lua", "name2id", target_name )
    -- if not target_id then
    --     user.send_request( "send_error_id", {error_id=constant.ROLE_NOT_EXIST})
    --     -- syslog.warn("role_send_mail not target_role: ", user.account,target_name)
    --     return
    -- end

    -- if target_id == user.account then 
    --     syslog.warnf("role_send_mail not send self :",user.account)
    --     return 
    -- end

    -- if item_list and type(item_list) == "table" then
    --     if not user.CMD.try_remove_item_list( item_list ) then
    --         syslog.warnf("role_send_mail item not enought :",user.account)
    --         return 
    --     end
    --     user.CMD.remove_item_list( item_list )
    -- end

    -- mail_info = {
    --     role_info = {
    --         role_id = user.account,
    --         nickname = user.character.general.nickname,
    --         race = user.character.general.race,
    --         level = user.character.attribute.level,
    --     },
    --     title = title,
    --     content = content,
    --     time = math.floor(skynet.time()),
    --     type = constant.Player,
    --     -- status = constant.AlreadySend,
    --     mail_guid = skynet.call( mailserver ,"lua", "generate_mail_id"),
    --     -- target_id = target_id,
    --     -- target_name = target_name,
    --     item_list = item_list,
    -- }
    
    -- skynet.call( mailserver ,"lua", "send_mail_target", target_id, mail_info )
    -- -- save_mail( mail_info )
    -- return {mail_info = mail_info}
end

return handler

