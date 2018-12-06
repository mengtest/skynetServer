local skynet = require "skynet"
-- local sharedata = require "skynet.sharedata"

local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"
local constant = require "constant"
local helper = require "common.helper"

local RPC = {}
local CMD = {}
handler = handler.new (RPC, CMD)

local user
local database
local chatserver
local friendserver
local last_world_chat_time = 0
local last_send_private_chat_time = 0

handler:init (function (u)
	user = u
    database = skynet.queryservice ("database")
    chatserver = skynet.queryservice ("chat_server")
    friendserver = skynet.queryservice ("friend_server")
end)

---login send friend offline message    and  del db offlinemessage 
handler:login_init (function ()
    local offlinemessage = user.character.offlinemessage
    if next(offlinemessage) ~= nil then
        skynet.call(database, "lua", "friend", "delFriendOfflineMessage", user.character.id)
        user.send_request("rpc_send_offline_chat_info",{data = offlinemessage})
    end
end)

local function get_chat_info( message ,chat_type ,nowtime )
    return {
        role_info = {
            role_id = user.character.id,
            nickname = user.character.general.nickname,
            race = user.character.general.race,
            level = user.character.attribute.level,
        },
	    message = message, 
	    send_time = os.date("%Y%m%d%H%M%S",nowtime),
        chat_type = chat_type,
    }
end

function RPC.rpc_send_world_chat_message (args)
    local message = args and args.message
    if not message then 
        syslog.warn("rpc_send_world_chat_message message is nil account: ",user.account)
        return
    end  
    local message_len = helper.get_string_len( message )
    if message_len <= 0 or message_len > 100 then  --todo... gameConfig
        syslog.warn("rpc_send_world_chat_message message len illegal account: ".. user.account .. "  message_len: ",message_len)
        return
    end

    local nowtime = math.floor (skynet.time())
    local world_chat_cd_time = 2    --todo... gameConfig
    if last_world_chat_time + world_chat_cd_time > nowtime then
        syslog.warn("rpc_send_world_chat_message to fast account: ",user.account)
        return
    end
    last_world_chat_time = nowtime

    local chat_info = get_chat_info( message ,constant.World , nowtime )

    skynet.call(chatserver, "lua", "cmd_chat_world_broadcast",chat_info)
end

function RPC.rpc_send_target_chat_message( args )
    local target_id = args and args.target_id
    
    if not target_id or not args.message then 
        syslog.warn("rpc_send_target_chat_message param error :",user.account,target_id)
        return
    end

    local message_len = helper.get_string_len( args.message )
    if message_len <= 0 or message_len > 100 then  --todo... gameConfig
        syslog.warn("rpc_send_target_chat_message message len illegal account: ".. user.account .. "  message_len: ",message_len)
        return
    end

    if target_id == user.account then 
        syslog.warn("rpc_send_target_chat_message not send self : ",user.account)
        return 
    end
    local nowtime = math.floor (skynet.time())
    local private_chat_cd = 1
    if last_send_private_chat_time + private_chat_cd > nowtime then 
        syslog.warn("rpc_send_target_chat_message too fast :",user.account)
        return
    end
    
    local online = skynet.call( chatserver, "lua", "check_target_online", target_id )
    local is_friend = user.CMD.check_friends( target_id )
    if not online and not is_friend then
        syslog.warn("rpc_send_target_chat_message target not friend :",user.account ,target_id)
        return
    end

    local chat_info = get_chat_info( args.message ,constant.Private , nowtime )
    chat_info.target_id = target_id
    if online then 
        skynet.call(chatserver, "lua", "send_private_chat_info", chat_info )
    else 
        skynet.call(database, "lua", "friend", "saveFriendOfflineMessage", chat_info)
    end
    last_send_private_chat_time = nowtime
    return { chat_info = chat_info }
end

function CMD.send_chat_info( chat_info )
    user.send_request ("rpc_send_chat_info",{ data = chat_info })
end

return handler

