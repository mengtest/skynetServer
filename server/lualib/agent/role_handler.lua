local skynet = require "skynet"
local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"
local constant = require "constant"
local helper = require 'common.helper'
local dump = require "common.dump"

local complete = require 'config.complete'
print('------------------------------------')

for k,v in pairs(complete) do
	print(k)
	if type(v) == 'table' then
		for kk,vv in pairs(v) do
			print(kk,vv)
		end
	else
		print(v)
	end
end

local table_insert = table.insert
local RPC = {}
local CMD = {}
handler = handler.new (RPC, CMD)

local user
local learnConfig

handler:init (function (u)
    user = u
    database = skynet.queryservice ("database")
end)


handler:login_init (function ()
	learnConfig = skynet.call(database, "lua", "gameconfig", "GetLearnConfig")
end)

function CMD.on_new_day_come_role()
	
end


function RPC.GetLearnInfo( args )
	return {sure=true}
end

function RPC.heartbeat()
	--can to do someting
end



return handler

