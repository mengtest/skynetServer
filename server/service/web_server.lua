local skynet = require "skynet"
-- local socket = require "socket"
local socket = require "skynet.socket"
local syslog = require "syslog"
local httpd = require "http.httpd"
local dbpacker = require "db.packer"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local uuid = require "uuid"

local table = table
local string = string
local agent = {}

local nSlave = 8

local CMD = {}

function CMD.open ()
    syslog.debugf("--- web server open")
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat webserver")
end

local traceback = debug.traceback
skynet.start(function()
    for i= 1, nSlave do
        agent[i] = skynet.newservice('web_slave', nSlave, skynet.self())
    end
    local balance = 1
    local id = socket.listen("0.0.0.0", 8001)
    skynet.error("Listen web port 8001")
    socket.start(id , function(id, addr)
        skynet.error(string.format("%s connected, pass it to agent :%08x", addr, agent[balance]))
        skynet.send(agent[balance], "lua",'web', id)
        balance = balance + 1
        if balance > #agent then
            balance = 1
        end
    end)

    skynet.dispatch ("lua", function (_, _, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warnf ("unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, ...)
        if not ok then
            syslog.warnf ("handle message(%s) failed : %s", command, ret)
            -- kick_self ()
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)