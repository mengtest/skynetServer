local skynet = require "skynet"
local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"
local constant = require "constant"
local helper = require 'common.helper'
local dump = require "common.dump"

local config = require 'config.0'
local tables = {}

tables[1] = require 'config.1'
tables[2] = require 'config.2'
tables[3] = require 'config.3'
tables[4] = require 'config.4'
tables[5] = require 'config.5'
tables[6] = require 'config.6'
tables[7] = require 'config.7'
tables[8] = require 'config.8'
tables[10] = require 'config.10'
tables[11] = require 'config.11'
tables[12] = require 'config.12'
tables[13] = require 'config.13'
tables[14] = require 'config.14'

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
	
end)

function CMD.on_new_day_come_role()
	
end


function RPC.GetLearnInfo( args )
	return {sure=true}
end

function RPC.GetGradeInfo( args )
	local grade = args.grade
	local term = args.term
	print('-------------',grade,term)
	if not grade or not term then 
		return
	end
	local gradeInfo = {}
	for _,v in pairs(config) do
		if v.grade == grade and v.term == term then
			local info = {
				id=v.id,
				grade=v.grade,
				term=v.term,
				unit=v.unit,
				uText=v.uText,
				moudle=v.moudle
			}
			table_insert(gradeInfo,info)
		end
	end
	return {info = gradeInfo}
end

local function getTabId(grade, term, unit, moudleId)
	local tId,id
	for _,v in pairs(config) do
		if v.grade == grade and v.term == term and v.unit == unit then
			for i=1,8 do
				for index, mIds in pairs(v['content'..i]) do
					if type(mIds) == 'table' then
						for _, mId in pairs(mIds) do
							if mId == moudleId then
								tId = i
								id = v['table'..i][index]
								break
							end
						end
					elseif mIds == moudleId then
						tId = i
						id = v['table'..i][index]
					end
					if tId then break end
				end
				if tId then break end
			end
		end
		if tId then break end
	end
	return tId,id
end

function RPC.GetMoudleInfo( args )
	local grade = args.grade
	local term = args.term
	local unit = args.unit
	local moudleId = args.moudleId
	print('-------------moudle',grade,term,moudleId)
	if not (grade and term and moudleId) then 
		return
	end
	local tId,id = getTabId(grade, term, unit, moudleId)
	assert(id,'id not exist')
	if not id then return end
	if type(id) == 'table' then
		for k,v in pairs(id) do
			print(k,v,tId)
		end
		if tId == 4 then
			local infoList = {}
			for _, myId in pairs(id) do
				local tInfo = tables[tId][myId]
				local cInfo = {}
				for _,cid in pairs(tInfo.userIconStep) do
					table_insert( cInfo, tables[tInfo.tableId][cid])
				end
				table_insert(infoList,{
					id = tInfo.myId,
					cStatements = tInfo.cStatements,
					statements = tInfo.statements,
					headline = tInfo.headline,
					userIconStep = tInfo.userIconStep,
					sVoice = tInfo.sVoice,
					contentInfo = cInfo,
				})
			end	
			user.send_request("SyncMoudle4Info",{infoList = infoList})
		end
	else
		local tInfo = tables[tId][id]
		if not tInfo then return end
		if tId == 1 then
			local cInfo = {}
			for _,id in pairs(tInfo.textIds) do
				table_insert( cInfo, tables[tInfo.tableIds][id])
			end
			user.send_request("SyncMoudle1Info",{
				id = tInfo.id,
				statement = tInfo.statement,
				cStatement = tInfo.cStatement,
				voice = tInfo.voice,
				contentInfo = cInfo,
			})
		elseif tId == 2 then
			local cInfo = {}
			for _,id in pairs(tInfo.worldIds) do
				table_insert( cInfo, tables[tInfo.tableId][id])
			end
			user.send_request("SyncMoudle2Info",{
				id = tInfo.id,
				cStatements = tInfo.cStatements,
				statements = tInfo.statements,
				voices = tInfo.voices,
				contentInfo = cInfo,
			})
		elseif tId == 3 then
			local cInfo = {}
			for _,id in pairs(tInfo.textIds) do
				table_insert( cInfo, tables[tInfo.tableId][id])
			end
			
			user.send_request("SyncMoudle3Info",{
				id = tInfo.id,
				cStatements = tInfo.cStatements,
				statements = tInfo.statements,
				voices = tInfo.voices,
				steps = tInfo.steps,
				contentInfo = cInfo,
			})
		elseif tId == 5 then
			user.send_request("SyncMoudle5Info",{
				id = tInfo.id,
				unpackVoice = tInfo.unpackVoice,
				sVoice = tInfo.sVoice,
				soundmark = tInfo.soundmark,
				wordUnpack = tInfo.wordUnpack,
				contentInfo = {tables[tInfo.tableId][tInfo.matchId]},
			})
		elseif tId == 6 then
			user.send_request("SyncMoudle6Info",{
				id = tInfo.id,
				cStatements = tInfo.cStatements,
				scene2st = tInfo.scene2st,
				scene1 = tInfo.scene1,
				scene2sb = tInfo.scene2sb,
				scene1sb = tInfo.scene1sb,
				clues2 = tInfo.clues2,
				scene1text = tInfo.scene1text,
				statements = tInfo.statements,
				scene2 = tInfo.scene2,
				cluesVoice2 = tInfo.cluesVoice2,
				scene1voice = tInfo.scene1voice,
				title = tInfo.title,
				clues1 = tInfo.clues1,
				sVoice = tInfo.sVoice,
				scene1st = tInfo.scene1st,
				scene2voice = tInfo.scene2voice,
				scene2text = tInfo.scene2text,
			})
		elseif tId == 7 then
			user.send_request("SyncMoudle7Info",{
				id = tInfo.id,
				cStatements = tInfo.cStatements,
				statements = tInfo.statements,
				wordVoice = tInfo.wordVoice,
				expandIcon = tInfo.expandIcon,
				voice = tInfo.voice,
				expandVoice = tInfo.expandVoice,
				icon = tInfo.icon,
				expandWord = tInfo.expandWord,
			})
		elseif tId == 8 then
			local cInfo = {}
			for _,id in pairs(tInfo.wordId) do
				table_insert( cInfo, tables[tInfo.tableId][id])
			end
			local cInfo1 = {}
			for _,id in pairs(tInfo.textId) do
				table_insert( cInfo1, tables[tInfo.chaosTableId][id])
			end
			user.send_request("SyncMoudle8Info",{
				id = tInfo.id,
				cStatements = tInfo.cStatements,
				statements = tInfo.statements,
				voice = tInfo.voice,
				weight = tInfo.weight,
				contentInfo1 = cInfo,
				contentInfo2 = cInfo1,
			})
		end
	end
	
	return {status = true}
end

function RPC.heartbeat()
	--can to do someting
end



return handler

