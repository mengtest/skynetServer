local skynet = require "skynet"
local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"
local constant = require "constant"
local helper = require 'common.helper'
local dump = require "common.dump"

local table0 = require 'config.0'
local table1 = require 'config.1'
local table2 = require 'config.2'
local table3 = require 'config.3'
local table4 = require 'config.4'
local table5 = require 'config.5'
local table6 = require 'config.6'
local table7 = require 'config.7'
local table8 = require 'config.8'
local table10 = require 'config.10'
local table11 = require 'config.11'
local table12 = require 'config.12'
local table13 = require 'config.13'
local table14 = require 'config.14'

-- dump(table0)

-- for k,v in pairs(table5) do
-- 	print(k)
-- 	if type(v) == 'table' then
-- 		for kk,vv in pairs(v) do
-- 			print(kk)
-- 			if type(vv) == 'table' then
-- 				for kkk,vvv in pairs(vv) do
-- 					print(kkk,vvv)
-- 				end
-- 			else
-- 				print(vv)
-- 			end
-- 		end
-- 	else
-- 		print(v)
-- 	end
-- end

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
	local gradeInfo = {}
	for _,v in pairs(table0) do
		local info = {id=v.id,grade=v.grade,term=v.term,unit=v.unit,uText=v.uText}
		table_insert(gradeInfo,info)
	end
	user.send_request("sync_grade_info",{info = gradeInfo})
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

