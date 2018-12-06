local skynet = require "skynet"
local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"
local constant = require "constant"
local helper = require 'common.helper'

local table_insert = table.insert
local dump = require "common.dump"
local RPC = {}
local CMD = {}
handler = handler.new (RPC, CMD)

local user
local userInfo

local database
local DayActivitePointConfig
local DayActivityConfig
local itemConfig
local LevelConfig 		-- 升级配置

local already_receive_reward_id
local already_receive_active_id
local record_tbl

handler:init (function (u)
    user = u
    database = skynet.queryservice ("database")
    userInfo = u and u.character
end)

local function get_sign_in_day( last_sign_in_time )
	last_sign_in_time = last_sign_in_time or 0
	local current_sign_in_day = userInfo.gameinfo.CurrentSignInDay or 0
	--当前签到天数 > 最大签到天数  重置
	if current_sign_in_day > 7 then
		return 0
	end
	local not_today = helper.check_another_day( last_sign_in_time )
	--当前天数为最大天数 并且 上次签到时间不是今天 重置
	if current_sign_in_day == 7 and not_today then
		return 0
	end

	--上次签到和今天是同一天  
	if not not_today then
		return current_sign_in_day
	end
	--上次签到时间  是 昨天
	if not helper.check_another_day( last_sign_in_time + 86400 ) then
		return current_sign_in_day
	end
	return 0
end

local function init_sign_in_reward_id( receive_sign_in_rewardids )
	for _,v in ipairs(SignInConfig) do
		if v.Type == 2 then
			table_insert(receive_sign_in_rewardids,v.Id)
		end
	end
end

local function update_game_info()
	local receive_sign_in_rewardids = userInfo.gameinfo.ReceiveSignInRewardIds or {}
	if not next(receive_sign_in_rewardids) then
		init_sign_in_reward_id( receive_sign_in_rewardids )
		userInfo.gameinfo.ReceiveSignInRewardIds = receive_sign_in_rewardids
		userInfo.gameinfo.AccumSignInDay = 0
	end

	userInfo.gameinfo.CurrentSignInDay = get_sign_in_day(userInfo.gameinfo.LastSignInTime)
    CMD.save_game_info()
    user.send_request( 'sync_game_info' ,userInfo.gameinfo )
	itemConfig = skynet.call (database, "lua", "gameconfig", "get_item_config")
	LevelConfig = skynet.call (database, "lua", "gameconfig", "get_level_config")
end

handler:login_init (function ()
	
end)

function CMD.on_new_day_come_role()
	already_receive_reward_id = {}
 	already_receive_active_id = {}
 	record_tbl = {}
 	userInfo.active_point = 0
 	update_game_info()
 	user.send_request('on_new_day_come_role')
end

function CMD.update_record( type, count )
 	record_tbl[type] = (record_tbl[type] or 0) + count
end

local function getDayActivityConfig( id )
	for _,v in ipairs(DayActivityConfig) do
		if v.Id == id then
			return v
		end
	end
end

local function getDayActivitePointConfig( id )
	for _,v in ipairs(DayActivitePointConfig) do
		if v.Id == id then
			return v
		end
	end
end

local function can_receive_reward( id )
	for _,v in ipairs(already_receive_reward_id) do
		if v == id then return end
	end
	return true
end

local function random_range01(rate)
	return math.random() < rate
end

local function do_reward2( config )
	local reward_nimbus = config.RewardNimbus
	local reward_rune = config.RewardRune
	local rate = config.Rate

	if reward_nimbus and reward_nimbus > 0 then
		user.CMD.add_nimbus( reward_nimbus )
	end
	if reward_rune and rate and reward_rune > 0 and rate > 0 then
		if random_range01(rate)  then
			user.CMD.add_rune( reward_rune )
		end
	end
end

function RPC.get_day_active_reward( args )
	local id = args.id 
	if not id then 
		syslog.warn("get_day_active_reward param error : ",user.account)
		return
	end

	if not can_receive_reward(id) then
		syslog.warn("get_day_active_reward received : ",user.account,id)
		return 
	end

	local config = getDayActivitePointConfig(id)
	if not config then
		syslog.warn("get_day_active_reward id error : ",user.account,id)
		return 
	end
	-- if userInfo.active_point < config.ActivitePoint then
	-- 	syslog.warn("get_day_active_reward active_point not enought: ",user.account,id)
	-- 	return 
	-- end
	do_reward2( config )
	table_insert( already_receive_reward_id, id )
	return { id=id }
end

local function check_record( record_type, record_count )
	local count = record_tbl[record_type]
	if count and count >= record_count then 
		return true
	end	
end

local function check_activity_finish( config )
	local record_type = config.RecordType
	if record_type and record_type > 0 then
		if not check_record( record_type, record_count ) then
			return false
		end
	end
	if config.HaveMouthCard and user.mouth_card_count <= 0 then
		return false
	end
	return true
end


local function can_receive_active( id )
	for _,v in ipairs(already_receive_active_id) do
		if v == id then return false end
	end
	return true
end

function RPC.get_day_active( args )
	local id = args.id 
	if not id then 
		syslog.warn("get_day_active param error: ",user.account)
		return
	end

	if not can_receive_active(id) then
		syslog.warn("get_day_active received: ",user.account)
		return 
	end

	local config = getDayActivityConfig(id)
	if not config then
		syslog.warn("get_day_active id error: ",user.account)
		return 
	end

	-- if not check_activity_finish( config ) then 
	-- 	syslog.warn("get_day_active not finish: ",user.account)
	-- 	return
	-- end

	local reward_active_point = config.RewardActivePoint 
	-- userInfo.active_point = userInfo.active_point + reward_active_point
	table_insert( already_receive_active_id, id )
	return { id = id, reward_active_point = reward_active_point }
end

---------->>>>>>>>>>>>>>>>-----signIn------<<<<<<<<<<<<<<<-------------

function CMD.save_game_info()
	skynet.call (database, "lua", "game", "save_game_info", userInfo.id, userInfo.gameinfo)
end

local function get_signin_config( id , rtype )
	for _,v in pairs(SignInConfig) do
		if v.Id == id and v.Type == rtype then
			return v
		end
	end
end

function RPC.every_day_sign_in()
	local last_sign_in_time = userInfo.gameinfo.LastSignInTime or 0
	if not helper.check_another_day( last_sign_in_time ) then
		syslog.warn("every_day_sign_in already signIn: ",user.account)
		return
	end

	local vip_config = user.CMD.get_vip_config( userInfo.vip )
	local multiple = (vip_config and vip_config.SignInMultiple) or 1

	local current_sign_in_day = userInfo.gameinfo.CurrentSignInDay + 1
	local nowtime = os.time()

	userInfo.gameinfo.LastSignInTime = nowtime
	userInfo.gameinfo.CurrentSignInDay = current_sign_in_day

	local config = get_signin_config( current_sign_in_day , 1 )
	user.CMD.do_reward((config.RewardRune or 0)*multiple,(config.RewardNimbus or 0)*multiple,config.ItemIds,multiple)
	userInfo.gameinfo.AccumSignInDay = (userInfo.gameinfo.AccumSignInDay or 0) + 1
	CMD.save_game_info()
	return { current_sign_in_day = current_sign_in_day, last_sign_in_time=nowtime, accum_sign_in_day = userInfo.gameinfo.AccumSignInDay }
end

local function find_receive_accum_reward( id )
	for k,v in ipairs( userInfo.gameinfo.ReceiveSignInRewardIds ) do
		if v == id then 
			return k
		end
	end
end

function RPC.receive_accum_sign_in_reward( args )
	local reward_id = args and args.reward_id
	if not reward_id then 
		syslog.warn("receive_accum_sign_in_reward param error : ",user.account)
		return 
	end
	if reward_id > (userInfo.gameinfo.AccumSignInDay or 0) then
		syslog.warn("receive_accum_sign_in_reward accum not enought : ",user.account,reward_id)
		return
	end
	local config = get_signin_config( reward_id , 2 )
	if not config then
		syslog.warn("receive_accum_sign_in_reward not can receive : ",user.account)
		return
	end
	local index = find_receive_accum_reward( reward_id )
	if not index then
		syslog.warn("receive_accum_sign_in_reward received : ",user.account,reward_id)
		return
	end
	table.remove(userInfo.gameinfo.ReceiveSignInRewardIds,index)
	user.CMD.do_reward( config.RewardRune,config.RewardNimbus,config.ItemIds )
	CMD.save_game_info()
	return { reward_id = reward_id }
end

-------------------------------rookie_gift

local function get_rookie_gift()
	for _,v in pairs(itemConfig) do
		if v.Alias and v.Alias == 'Rookie' then
			return v
		end
	end
end

function RPC.receive_rookie_gift()
	if userInfo.gameinfo.ReceivedRookieGift then
		syslog.warn("receive_rookie_gift received : ",user.account)
		return
	end
	local rookie_gift_config = get_rookie_gift()
	assert(rookie_gift_config and rookie_gift_config.Item,'-------------rookie_gift_config error')
	user.CMD.do_reward( rookie_gift_config.AddRune, rookie_gift_config.AddNimbus,rookie_gift_config.Item)
	userInfo.gameinfo.ReceivedRookieGift = true
	CMD.save_game_info()
	return { received = true }
end

-----------------------------------------------------level_up---------------------

local function add_view_item( view_items, item_info )
	for _,v in pairs(view_items) do
		if v.item_id == item_info.item_id then
			v.num = v.num + item_info.num
			return
		end
	end
	table.insert(view_items,item_info)
end

local function do_level_up_reward( config, view_items )
	local addNimbus = config.Nimbus
	local addRune = config.Rune
	local items = config.Item

	if addNimbus then
		user.CMD.add_nimbus(addNimbus)
	end
	if addRune then
		user.CMD.add_rune(addRune)
	end

	if items then
		user.CMD.add_item_list(items)
		for _,v in pairs(items) do
			add_view_item( view_items, v )
		end
	end
end


function CMD.add_role_exp( add_exp )
	local level = user.character.attribute.level
	user.character.attribute.exp = user.character.attribute.exp + add_exp
	local current_exp = user.character.attribute.exp
	local levelConfig = LevelConfig[level]       
	local level_exp = levelConfig and levelConfig.Exp

	local view_items = {nil,nil,nil} 
	local addRune = 0
	local addNimbus = 0
	local level_up 

	while level_exp and current_exp >= level_exp do 
		current_exp = current_exp - level_exp
		level = level + 1 
		do_level_up_reward( levelConfig, view_items )
		addRune = addRune + levelConfig.Rune
		addNimbus = addNimbus + levelConfig.Nimbus
		levelConfig = LevelConfig[level]
		level_exp = levelConfig and levelConfig.Exp
		level_up = true
	end
	user.send_request("sync_level_exp", { level=level, exp=current_exp })
	user.character.attribute.exp = current_exp
	if level_up then
		local hp_max = levelConfig.Hp
		user.character.attribute.level = level
		user.send_request("level_up_reward", { item_list=view_items,exp_next=level_exp,nimbus=addNimbus,rune=addRune,hp_max=hp_max })
	end
	skynet.call (database, "lua", "game", "cmd_game_level_up", user.character.id, level, current_exp)
	return level_up
end

function RPC.heartbeat()
	--can to do someting
end



return handler

