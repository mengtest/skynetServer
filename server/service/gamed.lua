local skynet = require "skynet"

local gameserver = require "gameserver.gameserver"
local syslog = require "syslog"

local table = table
local logind = tonumber (...)

local gamed = {}
local pending_agent = {}
-- local pool = {}
local clear_pool = {}
local online_account = {}

local EXPIRE_CLEAN_TIME = 60

local function create_agent()
    return skynet.newservice ("agent", skynet.self())   
end


function gamed.open (config)
	syslog.notice ("gamed opened")

	-- local self = skynet.self ()
	-- local n = config.pool or 0
	-- for i = 1, n do
	-- 	table.insert (pool, skynet.newservice ("agent", self))
	-- end

    -- local webserver = skynet.uniqueservice ("web_server")
    -- skynet.call (webserver, "lua", "open")
    local timerserver = skynet.uniqueservice ("timer_server")
    skynet.call (timerserver, "lua", "open")
    -- local gdd = skynet.uniqueservice ("gdd")
    -- skynet.call (gdd, "lua", "open")
    local world = skynet.uniqueservice ("world")
    skynet.call (world, "lua", "open")
    -- local chatserver = skynet.uniqueservice ("chat_server")
    -- skynet.call (chatserver, "lua", "cmd_open")
    -- local laborserver = skynet.uniqueservice ("labor_server")
    -- skynet.call (laborserver, "lua", "open")
    -- local friendserver = skynet.uniqueservice ("friend_server")
    -- skynet.call (friendserver, "lua", "open")
    -- local mailserver = skynet.uniqueservice ("mail_server")
    -- skynet.call (mailserver, "lua", "open")
    -- local namehouse = skynet.uniqueservice ("name_house")
    -- skynet.call (namehouse, "lua", "open")
end

local function forward_agent(fd, id, session, isTraveler)
    print(string.format("************gamed forward_agent:%d %s", session or 0, id or "nil"))
    local agent = clear_pool[id] and clear_pool[id].agent
    clear_pool[id] = nil
    if not agent then
        agent = create_agent()
    end
    -- if #pool == 0 then
    --     agent = skynet.newservice ("agent", skynet.self ())
    --     syslog.noticef ("pool is empty, new agent(%d) created", agent)
    -- else
    --     agent = table.remove (pool, 1)
    --     syslog.debugf ("agent(%d) assigned, %d remain in pool", agent, #pool)
    -- end

    online_account[id] = { 
            agent = agent,
            isKick = false, -- 成功分配 agent 后被踢标记置为 false
            fd = nil,
            session = nil,
        }

    skynet.call (agent, "lua", "cmd_agent_open", fd, id, session, isTraveler)
    gameserver.deal_pending_msg (fd, agent)
    gameserver.forward (fd, agent) -- 在 gateserver 中 dispatch msg 是，直接重定向到对应的 agent
end

function gamed.command_handler (cmd, ...)
    -- print(string.format("************gamed.command_handler:"))
	local CMD = {}

	function CMD.cmd_gamed_close (agent, id, session)
        -- print(string.format("************gamed.cmd_gamed_close:%d %d", session, id))
        local info = online_account[id]
        if info ~= nil then
            if info.isKick then -- socket关闭后再处理再次登陆后分配agent
                syslog.warnf ("挤号重登处理, id:%d", id)
                forward_agent(info.fd, id)
            else
                online_account[id] = nil
            end 
        end
        syslog.debugf ("agent %d recycled", agent)
		-- table.insert (pool, agent)
        if clear_pool[id] then 
            skynet.send( clear_pool[id].agent, 'lua' ,"self_exit")
        end
        clear_pool[id] = { ['agent'] = agent,['expire_time'] = os.time() + EXPIRE_CLEAN_TIME }
	end

	function CMD.cmd_gamed_kick (agent, fd)
		gameserver.kick (fd)
	end

    function CMD.five_sec_tick ()
        local nowtime = os.time()
        for k,v in pairs(clear_pool) do
            if nowtime > v.expire_time then
                skynet.send(v.agent,'lua','self_exit')
                clear_pool[k] = nil
            end
        end
    end

	local f = assert (CMD[cmd])
	return f (...)
end

function gamed.auth_handler (session, token, isTraveler)
    -- syslog.debugf ("---------- gamed, %s", debug.traceback("", 1))
    -- print(string.format("************gamed.auth_handler:%d %s", session, token))
	return skynet.call (logind, "lua", "cmd_server_verify", session, token, isTraveler)	
end

function gamed.login_handler (fd, id, session, isTraveler)
    print(string.format("************gamed.login_handler:%d %s", session, id))
	local info = online_account[id]
    local agent = info and info.agent

    -- 多次登陆，类似挤号，保存相关信息
    -- 1. 账号在其他地方登陆, 
	if agent then 
		syslog.warnf ("multiple login detected for id %d", id)
        skynet.call (agent, "lua", "cmd_agent_other_login") -- 
		skynet.call (agent, "lua", "cmd_agent_kick", id) -- 用户重登，踢出之前的用户，然后在之前用户 sock 关闭后，再处理登陆
        info.isKick = true
        info.fd = fd
        info.session = session
    else
        forward_agent(fd, id, session,isTraveler)
	end
end

gameserver.start (gamed)
