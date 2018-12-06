local skynet = require "skynet"
local syslog = require "syslog"
require "skynet.manager"

local CMD = {}
local online_character = {}

function CMD.open ()
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat webserver")
end

local traceback = debug.traceback
skynet.start (function ()
	-- print("########## world start ##########")
	local self = skynet.self ()
    skynet.dispatch ("lua", function (_, source, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warnf ("unhandled world message(%s)", command)
            return skynet.ret ()
        end

        local function ret (ok, ...)
            if not ok then
                syslog.warnf ("handle world message(%s) failed", command)
                skynet.ret ()
            else
                skynet.retpack (...)
            end  
        end
        ret (xpcall (f, traceback , source, ...))
    end)
end)
