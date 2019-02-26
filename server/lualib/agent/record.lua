local skynet = require "skynet"
local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"
local constlocal skynet = require "skynet"
local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"
local constant = require "constant"
local helper = require 'common.helper'
local dump = require "common.dump"

local table_insert = table.insert
local RPC = {}
local CMD = {}
handler = handler.new (RPC, CMD)

local user
local learnConfig
local info

handler:init (function (u)
    user = u
    database = skynet.queryservice ("database")
end)

handler:login_init (function ()
	info = skynet.call(database, "lua", "ResultInfo", "getResultInfo", user.account)
end)

local function saveResultInfo( args )
	local moudleBase = args.moudleBase
	local grade = moudleBase.grade
	local term = moudleBase.term
	local unit = moudleBase.unit
	local moudleId = moudleBase.moudleId
	local canAdd = true
 	for _,v in pairs(info) do
		if v.moudleBase.grade == grade and v.moudleBase.term == term and v.moudleBase.unit == unit and v.moudleBase.moudleId == moudleId then
			canAdd = false
			v.order = args.order
			v.score[args.order] = args.score
		end
	end
	if canAdd then 
		table_insert(info,{moudleBase = moudleBase,order = args.order,score = {args.score}})
	end
end

function CMD.SaveResultInfo()
	if next(info) then
		local ret = skynet.call(database, "lua", "ResultInfo", "saveResultInfo", user.account, info)
		print("--------------------ret",ret)
	end
end

function RPC.SendLearnResultInfo( args )
	local moudleBase = args.moudleBase
	if not moudleBase then return end
	local grade = moudleBase.grade
	local term = moudleBase.term
	local unit = moudleBase.unit
	local moudleId = moudleBase.moudleId
	print('-------------SendLearnResultInfo',grade,term,unit,moudleId)
	if not (grade and term and moudleId and unit) then 
		return
	end
	local tId,id = user.CMD.GetTabId(grade, term, unit, moudleId)
	assert(id,'id not exist')

	if not id then return end
	if not args.order then return end

	local score = args.score
	if not score or score < 0 or score > 100 then return end
	saveResultInfo(args)
	return {status = true}
end

function RPC.GetResultInfo( args )
	local moudleBase = args.moudleBase
	if not moudleBase then return end
	local grade = moudleBase.grade
	local term = moudleBase.term
	local unit = moudleBase.unit
	local moudleId = moudleBase.moudleId
	print('-------------GetResultInfo',grade,term,unit,moudleId)

	if not (grade and term and moudleId and unit) then return end
	local tId,id = user.CMD.GetTabId(grade, term, unit, moudleId)
	assert(id,'id not exist')
	if not id then return end
	local MInfo = {}
	MInfo.moudleBase = moudleBase
	MInfo.score = {}	
	for _,v in pairs(info) do
		if v.moudleBase.grade == grade and v.moudleBase.term == term and v.moudleBase.unit == unit and v.moudleBase.moudleId == moudleId then
			MInfo.score = v.score
			MInfo.order = v.order or 0
			break
		end
	end
	return MInfo
end


return handler