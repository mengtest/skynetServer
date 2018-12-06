local syslog = require "syslog"
local assert = syslog.assert

local CMD = {}
local connection_handler

local function make_key (account)
	return connection_handler (account)
end

function CMD.init (ch)
	connection_handler = ch
	-- mongodb = mg
end

-- 更新符文石
function CMD.cmd_game_rune_revive(id, rune)
	-- print("-----------cmd_game_rune_revive---------")
	local mongodb = make_key(id)
	local ret = mongodb.Score:safe_update({ID = id}, {["$inc"] = {Rune = rune}})
	assert(ret)
end

-- 更新灵力
function CMD.cmd_game_update_nimbus(id, nimbus)
	local mongodb = make_key(id)
	local ret = mongodb.Score:safe_update({ID = id}, {["$inc"] = {Nimbus = nimbus}})
	assert(ret)
end

-- 升级
function CMD.cmd_game_level_up(id, level, exp)
	local mongodb = make_key(id)
	-- print("-----------cmd_game_level_up---------")
	local ret = mongodb.RoleInfo:safe_update({ID = id}, {["$set"] = {Level = level, Exp = exp}})
	assert(ret)
end

-- 经验更新
function CMD.cmd_game_exp_up(id, exp)
	local mongodb = make_key(id)
	-- print("-----------cmd_game_exp_up---------")
	local ret = mongodb.RoleInfo:safe_update({ID = id}, {["$set"] = { Exp = exp}})
	assert(ret)
end

function CMD.save_game_info( id , game_info )
	local mongodb = make_key(id)
	local ret = mongodb.GameInfo:safe_update({ID = id}, {["$set"] = { GameInfo = game_info }},true)
end

function CMD.get_latest_info( id )
	local mongodb = make_key(id)
	local info = {nil,nil,nil,nil,nil}

	local ret = mongodb.Account:find({ID = id},{['_id']=0,['Vip']=1,['VipExp']=1})
	if ret and ret:hasNext() then
		assert(ret:count() == 1)
		local acc = ret:next()
		info.Vip = acc.Vip
		info.VipExp = acc.VipExp
	end
	ret = mongodb.Score:find({ID = id})
	if ret and ret:hasNext() then
		assert(ret:count() == 1)
		local score = ret:next()
		info.Nimbus = score.Nimbus
		info.Rune = score.Rune	
	end

	ret = mongodb.GameInfo:find({ID = id},{['_id']=0})
	if ret and ret:hasNext() then
		assert(ret:count() == 1)
		local ginfo = ret:next()
		info.MonthCardExpireTime = ginfo.GameInfo.MonthCardExpireTime
		info.LastReceiveMonthCardTime = ginfo.GameInfo.LastReceiveMonthCardTime	
	end

	return info
end

function CMD.save_vip_get_weapon( id, weapon )
	local mongodb = make_key(id)
	local ret = mongodb.RoleInfo:safe_update({ID = id}, {["$set"] = { Weapon = weapon }},true)
	assert(ret)
end

function CMD.reset_rank_kill( id )
	local mongodb = make_key(id)
	local ret = mongodb.RoleInfo:safe_update({ID = id}, {["$set"] = { RankKillCount = 0 }})
	assert(ret)
end

function CMD.save_role_logout( id , time )
	local mongodb = make_key(id)
	local ret = mongodb.RoleInfo:safe_update({ID = id}, {["$set"] = { LastLogoutTime = time }},true )
	assert(ret)
end

function CMD.save_first_login( id,first_login )
	local mongodb = make_key(id)
	local ret = mongodb.RoleInfo:safe_update({ID = id}, {["$set"] = { FirstLogin = first_login }})
	assert(ret)
end

return CMD
