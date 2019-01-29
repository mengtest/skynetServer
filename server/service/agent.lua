local skynet = require "skynet"
local queue = require "skynet.queue"
-- local sharemap = require "skynet.sharemap"
local socket = require "skynet.socket"
local dbpacker = require "db.packer"
local FlagDef = require "config.FlagDef"
local dump = require "common.dump"
local ProtoProcess = require "proto.proto_process"
local syslog = require "syslog"
local protoloader = require "protoloader"
local netpack = require "skynet.netpack"
local helper = require 'common.helper'

----------- all handler begin ------------
local character_handler = require "agent.character_handler"
local gm_handler = require "agent.gm_handler"
local world_handler = require "agent.world_handler"
local friend_handler = require "agent.friend_handler"
local chat_handler = require "agent.chat_handler"
local mail_handler = require "agent.mail_handler"
local bag_handler = require "agent.bag_handler"
local shop_handler = require "agent.shop_handler"
local role_handler = require "agent.role_handler"
local pay_handler = require "agent.pay_handler"

local constant = require "constant"

----------- all handler end ------------

local chatserver
local friendserver

local cs = queue()
local assert = syslog.assert
local traceback = debug.traceback
local gamed = tonumber(...) 
local database
local user
local user_fd
local RPC = {} -- 在各个handler中各种定义处理，模块化，但必须确保函数不重名，所以一般 模块名_函数名

local host, proto_request = protoloader.load (protoloader.GAME)

local function send_msg (fd, msg)
	local package = string.pack (">s2", msg)
	socket.write (fd, package)
end

local session = {}

local function send_request (name, args)
	local str = proto_request (name, args)
	send_msg (user_fd, str)
end

local function kick_self ()
    -- send_request("sync_role_offline")
	skynet.call (gamed, "lua", "cmd_gamed_kick", skynet.self (), user_fd)
end

local last_heartbeat_time
local HEARTBEAT_TIME_MAX = 300*100 -- 30秒钟未收到消息，则判断为客户端失联
-- local function heartbeat_check ()
-- 	if HEARTBEAT_TIME_MAX <= 0 or not user_fd then return end

-- 	local t = last_heartbeat_time + HEARTBEAT_TIME_MAX - skynet.now ()
-- 	if t <= 0 then
--         syslog.debugf ("--- heatbeat:%s, last:%s, now:%s", HEARTBEAT_TIME_MAX, last_heartbeat_time, skynet.now() )

-- 		-- syslog.warn ("--- heatbeat check failed, exe kick_self()")
-- 		kick_self ()
-- 	else
-- 		skynet.timeout (HEARTBEAT_TIME_MAX, heartbeat_check)
-- 	end
-- end


local function handle_request (name, args, response)
	local f = REQUEST[name]
	if f then
        syslog.debugf ("--- 【C>>S】, request from client: %s", name)
		local ok, ret = xpcall (f, traceback, args)
        if not ret then
            dump(ret)
        end
		if not ok then
			syslog.warnf ("handle message(%s) failed : %s", name, ret) 
			kick_self ()
		else
			last_heartbeat_time = skynet.now () -- 每次收到客户端端请求，重新计时心跳时间
			if response and ret then -- 如果该请求要求返回，则返回结果
				send_msg (user_fd, response (ret))
			end
		end
	else
		syslog.warnf ("----- unhandled message : %s", name)
		kick_self ()
    end
end

skynet.register_protocol { -- 注册与客户端交互的协议
	name = "client",
	id = skynet.PTYPE_CLIENT,
    -- unpack = my_unpack,
    -- dispatch = my_dispatch,
}

-- todo: 这个要做成一个服务，确保随机到名字不重叠
local name_tbl = require "config.account_name"
local function get_random_name( ... )
    math.randomseed (os.time ())
    local index = math.random (#name_tbl)
    return name_tbl[index]
end

local CMD = {}

function CMD.test_dispatch(msg, sz)
    local msgstr = netpack.tostring(msg, sz)
    local type, name, args, response = host:dispatch (msgstr, #msgstr)
	if type == "REQUEST" then
        local f = RPC[name]
        if f then
            local ret = cs(f, args)
            if not ret then
                syslog.errorf("--- agent, rpc exec error, name:%s", name)
                -- kick_self ()
            else
                last_heartbeat_time = skynet.now () -- 每次收到客户端端请求，重新计时心跳时间
                if response and ret then -- 如果该请求要求返回，则返回结果
                	send_msg (user_fd, response (ret))
                end
            end
        else
            syslog.warnf("--- agent, no rpc name:%s", name)
            kick_self ()
        end
	else
        syslog.warningf ("invalid message type : %s", type) 
        kick_self ()
    end
end

function CMD.get_role_info()
    return user.character
end

local function register_handler()
    role_handler:register(user)
    gm_handler:register(user)
end

local function login_handler()
    role_handler:login()
end

local function send_user_info( info )
    send_request("client_user_info",info)
end

local function send_server_online()
    -- skynet.call (chatserver, "lua", "cmd_online", user.character.id)
    -- skynet.call (friendserver, "lua", "cmd_online", user.character)
end

local function init_user( info, fd, id, session )
    user = { 
        fd = fd, 
        account = id,
        session = session,
        info = info,
        RPC = {},
        CMD = CMD,
        send_request = send_request,
        IsTraveler = info.IsTraveler,
    }
end

local function do_first_reward()
    -- local mailserver = skynet.uniqueservice('mail_server')
    -- local mail_info = {
    --     title = 'GM大礼包',
    --     content = '恭喜玩家进入王者大陆!金戈铁马，冲锋陷阵，风里雨里，王者等你!异世界的勇士，开始新的征程吧！',
    --     time = os.time(),
    --     type = constant.System,
    --     status = constant.Undisposed,
    --     mail_guid = skynet.call( mailserver ,"lua", "generate_mail_id"),
    --     item_list = {
    --         {['item_id'] = 100001,['num']=2},
    --     },
    -- }
    -- user.CMD.receive_mail( mail_info )
end

function CMD.cmd_agent_open (fd, id, session)
    skynet.error('-----------------------------agent open')
    database = skynet.queryservice ("database")
    local info = skynet.call (database, "lua", "account", "cmd_account_loadInfo", id)
    if not info then
        info = skynet.call (database, "lua", "account", "cmd_account_loadInfo", constant.TravelerAccount)
        info.IsTraveler = true
    end
	init_user( info, fd, id, session ) --初始化user
	user_fd = fd
    RPC = user.RPC
    register_handler()  --注册handler
    -- todo: 暂时关闭心跳
	-- last_heartbeat_time = skynest.now () -- 开启心跳
	-- heartbeat_check ()
    send_server_online()   --通知服务器玩家上线
    send_user_info( info )  -- 下发客户端玩家信息
    login_handler() --调用玩家登录函数

    if info.FirstLogin then
        do_first_reward()
        info.FirstLogin = false
    end
    if info.LastLogoutTime and helper.check_another_day(info.LastLogoutTime) then
        CMD.on_new_day_come()
    end
    print("#############cmd_agent_open over#############")
end

local function save_data()

end

local function unregister_handler()
    gm_handler:unregister(user)
    role_handler:unregister(user)
    -- pay_handler:unregister(user)
end

local function send_server_offline()
    -- skynet.call (chatserver, "lua", "cmd_offline", user.character.id)
    -- skynet.call (friendserver, "lua", "cmd_offline", user.character.id, CMD.get_friends())
end
-- 此时socket已断开
function CMD.cmd_agent_close ()
    syslog.debugf ("--- cmd_agent_close:%s", user.account)

    local id = user.account
	local session = user.session
    local isTraveler = user.IsTraveler

    send_server_offline()
    unregister_handler()
	user = nil
	user_fd = nil
	RPC = nil
    
    if not isTraveler then
        skynet.call (database, "lua", "game", "save_role_logout", id ,os.time())
    end
    -- 通知服务器关掉这个agent的socket
	skynet.call (gamed, "lua", "cmd_gamed_close", skynet.self (), id, session)
end

-- todo: 下行挤号提示
function CMD.cmd_agent_other_login ()
    syslog.warn ("--- cmd_agent_other_login")
    --send_request("rpc_client_other_login")
end

-- 被相同账号挤掉踢下线时，需要保数据
function CMD.cmd_agent_kick ()
	syslog.debugf ("--- cmd_agent_kick")
    save_data()
    kick_self()
end

function CMD.on_new_day_come()
    
end

function CMD.self_exit()
    skynet.exit()
end

skynet.start (function ()
    print("-------------agent start:")
    skynet.dispatch ("lua", function (_, _, command, ...)
        print("--------------------------agent:",command)
		local f = CMD[command]
		if not f then
			syslog.warn("agnet unhandled agent message(%s)", command) 
			return skynet.ret ()
		end
        local function ret (ok, ...)
            if not ok then
                syslog.warnf ("handle message(%s) agent failed", command)
                skynet.ret ()
            else
                skynet.retpack (...)
            end  
        end
        ret (xpcall (f, traceback , ...))
	end)
end)
