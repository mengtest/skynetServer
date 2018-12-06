local skynet = require "skynet"
local mongo = require "skynet.db.mongo"
local bson = require "bson"
local config = require "config.mongo_config" -- 数据库配置文件

local account = require "db.account"
local character = require "db.character"
local friend = require "db.friend"
local bag = require "db.bag"
local mail = require "db.mail"
local game = require "db.game"
local gameconfig = require "db.gameconfig"
local gamelog = require "db.gamelog"

local syslog = require "syslog"

local group = {}
local ngroup

local host = {
	host = config.center.host,
	port = config.center.port,
	-- username = 'rpg'
	-- password = '111111'
	-- authmod = 'scram_sha1'
}

local function hash_str (str)
	local hash = 0
	string.gsub (str, "(%w)", function (c)
		hash = hash + string.byte (c)
	end)
	return hash
end

local function hash_num (num)
	local hash = num << 8
	return hash
end
  
function connection_handler (key)
	local hash
	local t = type (key)
	if t == "string" then
		hash = hash_str (key)
	else
		hash = hash_num (assert (tonumber (key)))
	end
	return group[hash % ngroup + 1]
end


local MODULE = {}
local function module_init (name, mod)
	MODULE[name] = mod
	mod.init (connection_handler)
end

local traceback = debug.traceback

local CMD = {}
function CMD.open()
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat database")
end


skynet.start (function ()
	--local mongodb = assert(mongo.client(host),"connect to mongodb fail:"..tostring(host))
	ngroup = #config.group
	local db_name = config.center.db_name
	for _, c in ipairs (config.group) do
		-- assert(mongo.client(c).db_name,"connect to mongodb fail")
    	table.insert (group, mongo.client(c)[db_name])
    end

	module_init ("gameconfig",gameconfig)
	module_init ("account", account) -- 不同模块分开处理
    module_init ("character", character)
	module_init ("friend", friend)
	module_init ("mail", mail)
	module_init ("game", game)
	module_init ("bag", bag)
	module_init ('gamelog',gamelog)

	skynet.dispatch ("lua", function (_, _, mod, cmd, ...)
        local thisf = CMD[mod] -- 本服务的cmd方法
        if thisf then
            thisf(cmd, ...)
            return skynet.ret ()
        end

		local m = MODULE[mod] -- 先找对应模块 character
		if not m then
			return skynet.ret ()
		end
		local f = m[cmd] -- 再找对应模块下对应的方法 character.reserve
		if not f then
			return skynet.ret ()
		end
		
		local function ret (ok, ...)
			if not ok then
				skynet.ret ()
			else
				skynet.retpack (...) -- 返回执行结果
			end

		end
		ret (xpcall (f, traceback, ...)) -- 执行方法，并返回
	end)
end)
