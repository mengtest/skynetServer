local skynet = require "skynet"
local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"
local constant = require "constant"
local helper = require 'common.helper'

local dump = require "common.dump"
local RPC = {}
local CMD = {}
handler = handler.new (RPC, CMD)

local user
local database

local userInfo

handler:init (function (u)
	user = u
    database = skynet.queryservice ("database")
end)

handler:login_init (function ()

end)


function RPC.PayCourse( args )
	local grade = args.grade
	local term = args.term
	print('-------------PayCourse',grade,term)
	if not grade or not term then return end
	if grade < 3 or grade > 6 then return end
	if term ~= 1 and term ~= 2 then return end 
	if user.CMD.CheckPayInfo(grade,term) then return {status = false} end
	local ret = skynet.call(database, "lua", "account", "SavePayInfo", user.account, grade, term)
	if not ret then return end	
	user.CMD.SetPayInfo(grade,term)
	return {status = true}
end


return handler
