local skynet = require "skynet"
local syslog = require "syslog"
local dbpacker = require "db.packer"
local dump = require "common.dump"

local FlagOffline = 0
local FlagOnline = 1

local onlineTab = {}  --online player
local table = table
local assert = syslog.assert

local database

-- local world_history_chat = {}

local CMD = {}

function CMD.clear_all_player()
    for k,v in pairs(onlineTab) do
        skynet.fork(function()
            skynet.send(v.agent, 'lua', 'cmd_agent_kick')
        end)
    end
end

function CMD.cmd_open ( _ , conf )
    database = skynet.uniqueservice ("database")
end

function CMD.cmd_online(source, account)
    local accInfo = {
        account = account,
        agent = source,
        online = FlagOnline,
    }
    onlineTab[account] = accInfo
end


function CMD.cmd_offline( _ , account)
    local accInfo = onlineTab[account]
    assert(accInfo, string.format("Error, not found account:%d", account))

    onlineTab[account] = nil
end

function CMD.check_target_online ( _, target_id )
    if not target_id then return end
    return onlineTab[target_id] ~= nil 
end

function CMD.getOnline()
    return onlineTab
end

local function send_chat_info( target_agent , chat_info )
    skynet.send( target_agent, "lua", "send_chat_info", chat_info)
end
------world chat
function CMD.cmd_chat_world_broadcast( _ , chat_info)
    local role_id = chat_info.role_info.role_id
    local accInfo = onlineTab[role_id]
    assert(accInfo, string.format("Error, not found role_id:%d", role_id))

    for _,v in pairs(onlineTab) do
        send_chat_info(v["agent"],chat_info)
    end
end

------private chat

function CMD.send_private_chat_info( _ , chat_info )
    local target_info = onlineTab[chat_info.target_id]
    if not target_info then return end
    send_chat_info(target_info["agent"],chat_info)
end

local traceback = debug.traceback
skynet.start (function ()
    skynet.dispatch ("lua", function ( _, source, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warnf ("unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, source, ...)
        if not ok then
            syslog.warnf ("handle message(%s) failed : %s", command, ret)
            -- kick_self ()
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)