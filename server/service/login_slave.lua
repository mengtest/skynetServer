﻿local skynet = require "skynet"
local socket = require "skynet.socket"
local syslog = require "syslog"
local srp = require "srp"
local aes = require "aes"
local uuid = require "uuid"
local dump = require "common.dump"
--local ProtoProcess = require "proto.proto_process"
local protoloader = require "protoloader"
local cjson = require "cjson"
local uce = require "user_center_encrypt"

local traceback = debug.traceback
local assert = syslog.assert

local master
local database
local host
local auth_timeout
local session_expire_time
local session_expire_time_in_second
local connection = {}
local saved_session = {}

local slaved = {}
local CMD = {}
local RPC = {}

local travelerId = 0
local lastTime = 0
-- todo: 认证失败，需要下行协议通知客户端

local function close_fd (fd)
	if connection[fd] then
		socket.close (fd)
		connection[fd] = nil
	end
end

local function read (fd, size)
    -- print("read:"..size)
	return socket.read (fd, size) or error ()
end

local function read_msg (fd)
	local s = read (fd, 2)
	local size = s:byte(1) * 256 + s:byte(2)
	local msg = read (fd, size)
	return host:dispatch (msg, size)
end

local function send_msg (fd, msg)
	local package = string.pack (">s2", msg)
	socket.write (fd, package)
end

function CMD.init (m, id, conf)
    master = m
    database = skynet.uniqueservice ("database")
    host = protoloader.load (protoloader.LOGIN)
    auth_timeout = conf.auth_timeout * 100
    session_expire_time = conf.session_expire_time * 100
    session_expire_time_in_second = conf.session_expire_time
end

function CMD.cmd_slave_auth (fd, addr)
    syslog.notice("----------- cmd_slave_auth ------------------------")
	connection[fd] = addr
	-- print("+++++++++++++cmd_slave_auth addr:"..addr)
	skynet.timeout (auth_timeout, function ()
		if connection[fd] == addr then
			syslog.warnf ("connection %d from %s auth timeout!", fd, addr)
			close_fd (fd)
		end
	end)

	socket.start (fd)
    socket.limit (fd, 8192)
    
    print("------------------------ loginserver auth begin ------------------------")
    local type_msg, name, args, response = read_msg (fd)

    print(type_msg, name, args, response)
    syslog.debugf("--- rpc name:%s", name)
	assert (type_msg == "REQUEST")
	if name == "logintest" then
		assert(#args.account > 0)
		local info = skynet.call (database, "lua", "account", "cmd_account_password_loadInfo", args.account, "666666")

		if info and info == 0 then
			skynet.error('-------------------password error',args.account)
			close_fd(fd)
			return
		end
		-- not account to do create
		if not info then
			print '-----------------------------------create account'
			skynet.call (database, "lua", "account", "cmd_account_create",uuid.gen (), args.account, "666666", "test", string.sub(addr, 1, string.find(addr, ":", 1) - 1))
			info = skynet.call (database, "lua", "account", "cmd_account_password_loadInfo", args.account, "666666")
		end

		-- dump(info, "----------------- logintest info:")
		if not info then 
			skynet.error("---------------------------account")
			return 
		end
		local session = skynet.call (master, "lua", "cmd_server_save_session", info.ID, "1", 0)

		local msg = response {
				session = session,
				token = "1",
				ip = "192.168.10.105",
				port = 9555,
				isTraveler = 0,
		}
		send_msg (fd, msg)
		close_fd(fd)
	elseif name == "travelerLogin" then
		local nowTime = os.time()
		if lastTime == nowTime then
			travelerId = travelerId + 1
		else
			travelerId = 0
			lastTime = nowTime
		end
		local id = nowTime..travelerId
		local session = skynet.call (master, "lua", "cmd_server_save_session", id, "1", 1)

		print("---------------------",id,session)
		local msg = response {
				session = session,
				token = "1",
				ip = "192.168.10.105",
				port = 9555,
				isTraveler = 1,
		}
		send_msg (fd, msg)
		close_fd(fd)
	elseif name == "login_user_center" then
		skynet.fork(function()
			local ip = string.sub(addr, 1, string.find(addr, ":", 1) - 1)
			local status, body = uce.post_get_userinfo_msg(args, ip)
			print("ip     =====>:", ip)
			print("status =====>:", status)
			print("body   =====>:", body)
			if status == 200 then
				body = string.gsub(body, ":null", ":\"\"")
				body = cjson.decode(body)

				dump(body, "----------------- body:")

				local info = skynet.call (database, "lua", "account", "cmd_user_center_loadInfo", body.data, ip)

				dump(info, "----------------- login_user_center info:")

				local token = args.access_token
				local session = skynet.call (master, "lua", "cmd_server_save_session", info.ID, token, 0)
				local msg = response {
						session = session,
						--token = saved_session[session].token,
						ip = "192.168.120.81",
						port = 9555,
						isTraveler = 0,
				}

				-- dump(saved_session, "----------------- login_user_center saved_session:")
				send_msg (fd, msg)

				close_fd(fd)
			else
				syslog.errorf("login_user_center error:%d %s", status, addr)
				close_fd(fd)
			end
		end)
	end
end

function CMD.cmd_slave_save_session (session, id, token, isTraveler)
	saved_session[session] = { id = id, token = token, isTraveler = isTraveler }
	skynet.timeout (session_expire_time, function ()
		if saved_session[session] then
			saved_session[session] = nil
		end
	end)
end


function CMD.cmd_slave_verify (session, secret, isTraveler)
	dump(saved_session, "----------------- cmd_slave_verify saved_session:")
	local t = saved_session[session]
    print("cmd_slave_verify session:",session,isTraveler,t.isTraveler)
	assert (secret == t.token) -- 验证token
	assert (isTraveler == t.isTraveler) -- 验证token
	t.token = nil

	return t.id
end

function CMD.open (conf)
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat loginslave")
end

local traceback = debug.traceback
skynet.start (function ()
    skynet.dispatch ("lua", function (_, _, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warnf ("login_slave, unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, ...)
        if not ok then
            syslog.warnf ("login_slave, handle message(%s) failed : %s", command, ret)
            -- kick_self ()
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)