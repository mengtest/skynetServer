local skynet = require "skynet"
local socket = require "skynet.socket"

local syslog = require "syslog"
-- local config = require "config.system"


local session_id = 1
local slave = {}
local nslave
local gameserver = {}

local CMD = {}

function CMD.open (conf)
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)

	for i = 1, conf.slave do
		local s = skynet.newservice ("login_slave")
        skynet.call (s, "lua", "init", skynet.self (), i, conf)
		skynet.call (s, "lua", "open")
		table.insert (slave, s)
	end
	nslave = #slave

	local host = conf.host or "0.0.0.0"
	local port = assert (tonumber (conf.port))
	local sock = socket.listen (host, port)

	syslog.noticef ("listen on %s:%d", host, port)

	local balance = 1
	socket.start (sock, function (fd, addr)
		local s = slave[balance]
		balance = balance + 1
		if balance > nslave then balance = 1 end
            syslog.debugf ("---@ loginslave, connection %d from %s, balance:%d", fd, addr, balance)
		skynet.call (s, "lua", "cmd_slave_auth", fd, addr)
	end)
end

function CMD.cmd_server_save_session ( id, token, isTraveler )
	local session = session_id
	session_id = session_id + 1

	s = slave[(session % nslave) + 1]
	skynet.call (s, "lua", "cmd_slave_save_session", session, id, token, isTraveler)
	return session
end

function CMD.cmd_server_challenge (session, challenge)
	s = slave[(session % nslave) + 1]
	return skynet.call (s, "lua", "cmd_slave_challenge", session, challenge)
end

function CMD.cmd_server_verify (session, token, isTraveler)
    print("loginserver cmd_server_verify session:"..session)
    print("loginserver cmd_server_verify token:",token,isTraveler)
	local s = slave[(session % nslave) + 1]
	return skynet.call (s, "lua", "cmd_slave_verify", session, token, isTraveler)
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat loginslave")
end

local traceback = debug.traceback
skynet.start (function ()
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
