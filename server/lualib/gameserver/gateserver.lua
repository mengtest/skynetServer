local skynet = require "skynet"
local netpack = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"
local syslog = require "syslog"

local gateserver = {}

local socket
local queue
local maxclient
local nclient = 0
local CMD = setmetatable ({}, { __gc = function () netpack.clear (queue) end })

local IP = {}

local connection = {}

function gateserver.open_client (fd)
	if connection[fd] then
		socketdriver.start (fd)
	end
end

function gateserver.close_client (fd)
	local c = connection[fd]
	if c then
        syslog.debugf("---------- gateserver.close_client")


		socketdriver.close (fd)
	end
end

function gateserver.forward (fd, agent)
	local c = connection[fd]
	if c then
		c.agent = agent
		syslog.debugf ("------------ start forward fd(%d) to agent(%d)", fd, agent)
	end
end

function gateserver.start (handler)

	function CMD.open (source, conf)
		local addr = conf.address or "0.0.0.0"
		local port = assert (tonumber (conf.port))
		maxclient = conf.maxclient or 64

		syslog.noticef ("--- gateserver, listen on %s:%d", addr, port)
		socket = socketdriver.listen (addr, port)
		socketdriver.start (socket)

		if handler.open then
			return handler.open (source, conf)
		end
	end

	local MSG = {}

	function MSG.open (fd, addr)
		if nclient >= maxclient then
			return socketdriver.close (fd)
		end

		local c = {
			fd = fd,
			addr = addr,
		}
		connection[fd] = c
		IP[fd] = addr
		nclient = nclient + 1 

		handler.connect (fd, addr)
	end

	local function close_fd (fd)
		local c = connection[fd]
		if c then
			local agent = c.agent
			if agent then
				syslog.noticef ("fd(%d) disconnected, closing agent(%d)", fd, agent)
				skynet.call (agent, "lua", "cmd_agent_close")
				c.agent = nil
			else
				if handler.disconnect then
					handler.disconnect (fd)
				end
			end

			connection[fd] = nil
			IP[fd] = nil
			nclient = nclient - 1
		end
	end

	function MSG.close (fd)
        syslog.debugf("--------------- socket 已断开，MSG.close")
		close_fd (fd) -- 不在这里关闭，因为有点延迟，agent 重登需要先 close 再 open。类似构造和析构的顺序
	end

	function MSG.error (fd, msg)
        syslog.debugf("--------------- socket 已断开，MSG.error")
		close_fd (fd)
	end

	local function dispatch_msg (fd, msg, sz)
		local c = connection[fd]
		local agent = c.agent
		if agent then -- 如果有对应的agent连接，则转发给对应的agent处理
			-- skynet.redirect (agent, 0, "client", 0, msg, sz)
			skynet.send (agent, "lua", "test_dispatch", msg, sz)
		else -- 否则让继承这个gateserver的服务中的handler.message处理
			handler.message (fd, msg, sz)
		end
	end

	MSG.data = dispatch_msg

	local function dispatch_queue ()
		local fd, msg, sz = netpack.pop (queue)
		if fd then
			skynet.fork (dispatch_queue)
			dispatch_msg (fd, msg, sz)

			for fd, msg, sz in netpack.pop, queue do
				dispatch_msg (fd, msg, sz)
			end
		end
	end

	MSG.more = dispatch_queue

	skynet.register_protocol {
		name = "socket",
		id = skynet.PTYPE_SOCKET,
		unpack = function (msg, sz)
			return netpack.filter (queue, msg, sz) 
		end,
		dispatch = function (_, _, q, type, ...)
			queue = q
			if type then
				return MSG[type] (...) 
			end
		end,
	}

    skynet.register_protocol {
        name = "client",
        id = skynet.PTYPE_CLIENT,
    }

	skynet.start (function ()
		skynet.dispatch ("lua", function (_, address, cmd, ...)
			local f = CMD[cmd]
			if f then
				skynet.retpack (f(address, ...))
			else
				skynet.retpack (handler.command (cmd, ...))
			end
		end)
	end)
end

return gateserver
