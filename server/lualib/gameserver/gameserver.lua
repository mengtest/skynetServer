local skynet = require "skynet"

local gateserver = require "gameserver.gateserver"
local syslog = require "syslog"
-- local netpack = require "skynet.netpack"
local protoloader = require "protoloader"

local Utils = require "common.utils"
local msg_define = require "proto.msg_define"
-- local Packer = require "proto.proto_packer"
local dump = require "common.dump"


local gameserver = {}
local pending_msg = {}

function gameserver.forward (fd, agent)
	gateserver.forward (fd, agent)
end

function gameserver.kick (fd)
	gateserver.close_client (fd)
end

function gameserver.deal_pending_msg(fd, agent)
    local queue = pending_msg[fd]
    if queue == nil then return end
    for _, t in pairs (queue) do -- 待处理消息逐一处理
        syslog.noticef ("forward pending message to agent %d", agent)
        --skynet.rawcall(agent, "client", t.msg, t.sz)
    end
    pending_msg[fd] = nil
end

function gameserver.start (gamed)
	local handler = {}

	local host, send_request = protoloader.load (protoloader.LOGIN)

	function handler.open (source, conf)
		return gamed.open (conf)
	end

	function handler.connect (fd, addr)
		syslog.noticef ("--- gameserver, connect from %s (fd = %d)", addr, fd)
		gateserver.open_client (fd)
	end

	function handler.disconnect (fd)
		syslog.noticef ("--- gameserver, fd (%d) disconnected", fd)
	end

    -- -- 由于本服务已经注册 socket 协议，所以不能封装到 proto_process.lua 中，该文件有包含 socket.lua，会导致重复注册 socket 协议错误
    -- local function my_read_msg(fd, msg, sz)
    --     local msg = netpack.tostring(msg, sz)
    --     local proto_id, params = string.unpack(">Hs2", msg)
    --     local proto_name = msg_define.id_2_name(proto_id)
    --     local paramTab = Utils.str_2_table(params)
    --     syslog.debugf("--- proto_name:%s", proto_name)
    --     dump(paramTab, "--- paramTab")
    --     return proto_name, paramTab
    -- end

	local function do_login (fd, msg, sz)
		print("************do_login:")
		-- local name, args = my_read_msg(fd, msg, sz)
		-- assert (name == "rpc_server_login_gameserver")
		-- assert (args.session and args.token)
		-- local session = tonumber (args.session) or error ()
		-- local account = gamed.auth_handler (session, args.token) or error ()
		-- assert (account)
		-- return account, session
		local type, name, args, response = host:dispatch (msg, sz)
		print(type, name, args, response)
		print(args.session , args.token, args.isTraveler)
		-- print("do_login type:"..type)
		-- print("do_login name:"..name)
		assert (type == "REQUEST")
		assert (name == "login")
		assert (args.session and args.token)
		local session = tonumber (args.session) or error ()
		print("do_login session:"..session)
		local id = gamed.auth_handler (session, args.token, args.isTraveler) or error ()
		assert (id)
		return id, session,args.isTraveler
	end

	local traceback = debug.traceback
	function handler.message (fd, msg, sz)
		print("************handler.message:")
		local queue = pending_msg[fd]
		if queue then -- 认证期间有多个数据发送上来，存储到队列中待处理
			table.insert (queue, { msg = msg, sz = sz })
		else
			pending_msg[fd] = {}

			print("************xpcall do_login:")
			local ok, id, session,isTraveler = xpcall (do_login, traceback, fd, msg, sz) -- 去登陆服认证
			if ok then
				syslog.noticef ("gameserver do_login auth ok, id:%d session:%d", id, session)
				gamed.login_handler (fd, id, session,isTraveler)
			else
				syslog.warnf ("%s login failed : %s", addr, id)
				gateserver.close_client (fd)
			end
		end
	end

	local CMD = {}
	function CMD.token (id, secret)
		local id = tonumber (id)
		login_token[id] = secret
		skynet.timeout (10 * 100, function ()
			if login_token[id] == secret then
				syslog.noticef ("account %d token timeout", id)
				login_token[id] = nil
			end
		end)
	end

	function handler.command (cmd, ...)
		-- print("************handler.command:")
		local f = CMD[cmd]
		if f then
			return f (...)
		else
			return gamed.command_handler (cmd, ...)
		end
	end

	return gateserver.start (handler)
end

return gameserver
