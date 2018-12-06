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

local MONTH_CARD_DAY_COUNT = constant.MONTH_CARD_DAY_COUNT

local vipConfig
local itemConfig
-- local payConfig

local userInfo

handler:init (function (u)
	user = u
    database = skynet.queryservice ("database")
    userInfo = user.character
end)

handler:login_init (function ()
	itemConfig = skynet.call (database, "lua", "gameconfig", "get_item_config")
	vipConfig = skynet.call (database, "lua", "gameconfig", "get_vip_config")
	-- payConfig = skynet.call (database, "lua", "gameconfig", "get_pay_config")

	user.send_request("sync_vip_config",{ vip_config=vipConfig })
	-- user.send_request("sync_pay_config",{ pay_config=payConfig })
end)


-- local function save_vip_info()
-- 	skynet.call (database, "lua", "game", "save_vip_info", userInfo.id, userInfo.vip,userInfo.vip_exp)
-- end

-- local function do_level_vip( addExp )
-- 	local vip = userInfo.vip
-- 	userInfo.vip_exp = (userInfo.vip_exp or 0) + addExp
-- 	local exp = userInfo.vip_exp

-- 	if userInfo.gameinfo.CanReceiveFirstGift == nil and exp >= 6 then
-- 		userInfo.gameinfo.CanReceiveFirstGift = true
-- 		user.CMD.save_game_info()
-- 		user.send_request( 'sync_first_can_receive' )
-- 	end

-- 	local config = CMD.get_vip_config( vip )
-- 	while config.Exp and config.Exp > 0 and config.Exp <= exp do
-- 		vip = vip + 1
-- 		config = CMD.get_vip_config( vip )
-- 	end
-- 	userInfo.vip = vip
-- 	save_vip_info()
-- 	user.send_request('sync_vip_info',{ vip=userInfo.vip, exp=userInfo.vip_exp })
-- end

--------------------->>>>>>>>>>>>>>>>>>>>>>>-------month_card----------------------

local function get_Alias_config( Alias )
	for _,v in pairs(itemConfig) do
		if v.Alias and v.Alias == Alias then
			return v
		end
	end
end

-- local function get_add_exp()
-- 	for _,v in pairs(payConfig) do
-- 		if v.Alias and v.Alias == 'Month' then
-- 			return v.AddExp
-- 		end
-- 	end
-- end

function RPC.receive_card_reward()
	local nowtime = os.time()
	local expire_time = userInfo.gameinfo.MonthCardExpireTime
	if not expire_time or expire_time < nowtime then
		syslog.warn ("receive_card_reward not pay moth card:" ,userInfo.id)
		return
	end
  	local last_receive_card_time = userInfo.gameinfo.LastReceiveMonthCardTime
	if last_receive_card_time and not helper.check_another_day( last_receive_card_time ) then
		syslog.warn ("receive_card_reward already moth card reward:" ,userInfo.id)
		return
	end

	local config = get_Alias_config( 'Month' )
	assert(config)
	user.CMD.do_reward( config.AddRune,config.AddNimbus,config.Item)

	userInfo.gameinfo.LastReceiveMonthCardTime = nowtime
	user.CMD.save_game_info()
	return { last_receive_card_time=nowtime }
end

-- function RPC.pay_month_card()
-- 	local expire_time = userInfo.gameinfo.MonthCardExpireTime
-- 	if expire_time and expire_time > os.time() then
--     	syslog.warn ("pay_month_card already pay moth card:" ,userInfo.id)
-- 		return
-- 	end
-- 	do_level_vip(get_add_exp())
-- 	userInfo.gameinfo.MonthCardExpireTime = helper.get_day_time_addtime(MONTH_CARD_DAY_COUNT * 86400)
-- 	user.CMD.save_game_info()
-- 	return { month_card_expire_time=userInfo.gameinfo.MonthCardExpireTime } 
-- end

--------------------->>>>>>>>>>>>>>>>>>>>>>>-------Vip----------------------

function CMD.get_vip_config( id )
	for _,v in pairs(vipConfig) do
		if v.Id == id then
			return v
		end
	end
end

-- local function get_pay_config( id )
-- 	for _,v in pairs(payConfig) do
-- 		if v.Id == id then
-- 			return v
-- 		end
-- 	end
-- end

-- local function do_pay_reward( config )
-- 	local vip_config = CMD.get_vip_config( userInfo.vip )
-- 	local nimbus_addon = (vip_config.PayNimbusAddon or 0) + 1
-- 	user.CMD.do_reward( config.AddRune,config.AddNimbus*nimbus_addon,config.Item)
-- 	do_level_vip( config.AddExp )
-- end

-- function RPC.pay_vip( args )
-- 	local pay_id = args and args.pay_id
-- 	if not pay_id then
-- 		syslog.warn ("pay_vip param error:" ,userInfo.id)
-- 		return
-- 	end
-- 	local config = get_pay_config( pay_id )
-- 	if not config then
-- 		syslog.warn ("pay_vip pay_id error:" ,userInfo.id, pay_id)
-- 		return
-- 	end

-- 	do_pay_reward(config)
-- 	return { pay_id = pay_id }
-- end

local function check_received_vip_reward( id )
	if userInfo.gameinfo.ReceiveVipRewards then
		for _,v in pairs(userInfo.gameinfo.ReceiveVipRewards) do
			if id == v then
				return true
			end
		end
	end
end

local function do_pay_trigger()
	if userInfo.gameinfo.CanReceiveFirstGift == nil and userInfo.vip_exp >= 6 then
		userInfo.gameinfo.CanReceiveFirstGift = true
		user.CMD.save_game_info()
		user.send_request('sync_first_can_receive')
	end
	local vip = userInfo.vip
	if not check_received_vip_reward( vip ) then
		local weapon = CMD.get_vip_config( vip ).Weapon
		if weapon then
			if not userInfo.gameinfo.ReceiveVipRewards then
				userInfo.gameinfo.ReceiveVipRewards = {nil,nil}
			end
			table.insert( userInfo.gameinfo.ReceiveVipRewards, vip )
			skynet.call (database, "lua", "game", "save_vip_get_weapon", userInfo.id, weapon )
			user.CMD.save_game_info()
			user.send_request( 'sync_change_weapon', { weapon = weapon } )
		end
	end	

end

function CMD.update_self_info()
	local update_info = skynet.call( database, 'lua', 'game', 'get_latest_info', userInfo.id )
	userInfo.vip = update_info.Vip
	userInfo.vip_exp = update_info.VipExp
	userInfo.gameinfo.MonthCardExpireTime = update_info.MonthCardExpireTime
	userInfo.gameinfo.LastReceiveMonthCardTime = update_info.LastReceiveMonthCardTime
	userInfo.rune = update_info.Rune
	userInfo.nimbus = update_info.Nimbus

	do_pay_trigger()

	user.send_request('sync_latest_info',{ update_info = update_info })
end

function RPC.receive_first_gift()
	if not userInfo.gameinfo.CanReceiveFirstGift then
		syslog.warn ("receive_first_gift not receive:" ,userInfo.id)
		return
	end
	local config = get_Alias_config( 'First' )
	assert(config)
	user.CMD.do_reward( config.AddRune,config.AddNimbus,config.Item)
	userInfo.gameinfo.CanReceiveFirstGift = false
	user.CMD.save_game_info()
	return { can_receive = false }
end

local function check_receive_vip_reward( vip_level )
	if not userInfo.gameinfo.ReceivedVips then
		userInfo.gameinfo.ReceivedVips = {}
	end
	for _, v in pairs(userInfo.gameinfo.ReceivedVips) do
		if v == vip_level then
			return
		end
	end
	return true
end

function RPC.receive_vip_reward( args )
	local vip_level = args and args.vip_level
	if not vip_level then
		syslog.warn ("receive_vip_reward not param: " ,userInfo.id)
		return
	end
	if vip_level < 0 or vip_level > userInfo.vip then
		syslog.warn ("receive_vip_reward vip not enought : " ,userInfo.id, vip_level,userInfo.vip)
		return
	end
	local vip_config = CMD.get_vip_config(vip_level)
	if not vip_config then
		syslog.warn ("receive_vip_reward param error : " ,userInfo.id, vip_level)
		return
	end
	if not check_receive_vip_reward( vip_level ) then
		syslog.warn ("receive_vip_reward received : " ,userInfo.id, vip_level)
		return
	end

	local item_id = vip_config.ItemId
	if item_id then
		user.CMD.add_templet_item( item_id , 1 )
	end
	table.insert( userInfo.gameinfo.ReceivedVips, vip_level )
	user.CMD.save_game_info()
	return { vip_level=vip_level }
end

function RPC.pay_success()
	CMD.update_self_info()
end

return handler
