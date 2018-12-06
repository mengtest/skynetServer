local skynet = require "skynet"
local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"
local constant = require "constant"

local dump = require "common.dump"
local RPC = {}
local CMD = {}
handler = handler.new (RPC, CMD)

local user
local database
local nameserver
local friendserver
local bags

local itemConfig

local use_item_expire_tbl

local LIMIT_ITEM_COUNT = 200000
local EVERY_MAX_ITEM_COUNT = 999

--背包采用整体存储
local function save_db()
    skynet.call(database, "lua", "bag", "save_item", user.character.id, bags)
end

handler:init (function (u)
	user = u
    database = skynet.queryservice ("database")
    nameserver = skynet.queryservice("name_house")
    friendserver = skynet.queryservice('friend_server')
end)

--处理离线时候玩家赠送的物品    这里会同步一下道具增加  后期如果不要在这里去掉
local function handle_offline_give_item()
	local offlinegiveinfo = user.character.offlinegiveinfo or {}
    if next(offlinegiveinfo) ~= nil then
        skynet.call(database, "lua", "friend", "delOfflineGiveInfo", user.character.id)
        for _,v in ipairs(offlinegiveinfo) do
        	CMD.add_item_list( {v.item_info} )
        end
    end
end

handler:login_init (function ()
	bags = user.character.bags or {}
	itemConfig = skynet.call (database, "lua", "gameconfig", "get_item_config")
	user.send_request( "sync_item_config", {item_config=itemConfig} ) 
 	user.send_request( "sync_bag", {bag=bags} )
	handle_offline_give_item()
end)

-- local function table_copy(object)      
--     local SearchTable = {}  

--     local function Func(object)  
--         if type(object) ~= "table" then  
--             return object         
--         end  
--         local NewTable = {}  
--         SearchTable[object] = NewTable  
--         for k, v in pairs(object) do  
--             NewTable[Func(k)] = Func(v)  
--         end     

--         return setmetatable(NewTable, getmetatable(object))      
--     end    
--     return Func(object)  
-- end

--只是简单的把道具数量为0清掉
local function clean_bags()
	for i=#bags,1,-1 do
		if bags[i].num <= 0 then
			table.remove(bags, i)
		end
	end
end

local function get_item_config( item_id )
	for _,v in pairs(itemConfig) do
		if v.ItemId == item_id then
			return v
		end
	end
end

function CMD.get_templet_item_num( item_id )
	if not item_id then return end
	local count = 0
	for _,v in pairs(bags) do
		if v.item_id == item_id then
			count = count + v.num
		end
	end
	return count
end

function CMD.try_remove_item_list( item_list ) 
	local items = {}
	for _,v in ipairs(item_list) do
		local item_id = v.item_id
		items[item_id] = (items[item_id] or 0) + v.num
	end

	for k,v in pairs(items) do
		if not CMD.try_remove_templet_item( k, v ) then return end
	end
	return true
end

--检查道具数量
function CMD.try_remove_templet_item( item_id , num )
	if num <= 0 then return end
	local count  = CMD.get_templet_item_num ( item_id )
	if count and count >= num then
		return true
	end
end

function CMD.remove_item_list( item_list )
	for _,v in ipairs( item_list ) do
		CMD.remove_templet_item( v.item_id , v.num )
	end
end

-- 道具变动  更新道具排行榜
local function check_change_rank( item_id )
	if item_id == constant.RANK_ITEM_ID then
		user.CMD.change_rank( constant.RankNimbusBottle, CMD.get_templet_item_num( item_id ) )
	end
end

function CMD.remove_templet_item( item_id , num )
	local is_clean
	local count = num
	for _ , v in ipairs(bags) do
		if v.item_id == item_id then
			if v.num > count then
				v.num = v.num - count
				count = 0
				break
			else
				count = count - v.num
				v.num = 0
				is_clean = true
			end
		end
	end
	if is_clean then
		clean_bags()
	end
	save_db()
	user.send_request("bag_item_change",{item_info = {item_id = item_id,num = num},is_add=false})
	check_change_rank( item_id )
	return count == 0
end

function CMD.get_bags()
	clean_bags()
	return bags
end

local function sync_score()
	user.send_request("update_score", {nimbus = user.character.nimbus,rune = user.character.rune} )
end

function CMD.add_nimbus( addNimbus )
	if addNimbus < 0 then
		assert(0 <= user.character.nimbus + addNimbus)
	end
	user.character.nimbus = user.character.nimbus + addNimbus
	if user.character.nimbus < 0 then
		user.character.nimbus = 0
	end
	skynet.call (database, "lua", "game", "cmd_game_update_nimbus", user.character.id, addNimbus)
	sync_score()
	user.CMD.change_rank( constant.RankNimbus, user.character.nimbus )
end

function CMD.add_rune( addRune )
	if addRune < 0 then
		assert( 0 <= user.character.rune + addRune)
	end	
	user.character.rune = user.character.rune  + addRune
	if user.character.rune < 0 then
		user.character.rune = 0
	end
	skynet.call (database, "lua", "game", "cmd_game_rune_revive", user.character.id, addRune)
	sync_score()
	user.CMD.change_rank( constant.RankRune, user.character.rune )
end


function CMD.add_templet_item( item_id , num )
	assert(num > 0 and num <= 600)
	local config = get_item_config(item_id)
	assert(config)
	if config.ItemType == constant.ITEMGIFT and config.Item then
		CMD.do_use_item( config )
		return CMD.add_item_list( config.Item, num )
	end

	local count = CMD.get_templet_item_num(item_id)
	local item_info = {item_id = item_id,num = num}
	if not count or count <= 0 then
		table.insert( bags, item_info )
	elseif count + num <= LIMIT_ITEM_COUNT then 
		for _,v in pairs(bags) do
			if v.item_id == item_id then
				v.num = v.num + num  
				if v.num > EVERY_MAX_ITEM_COUNT then
					table.insert( bags, {item_id = item_id,num = v.num - EVERY_MAX_ITEM_COUNT} )
					v.num = EVERY_MAX_ITEM_COUNT
				end
				break
			end
		end
	end
	save_db()
	user.send_request("bag_item_change",{item_info = item_info,is_add=true})
	check_change_rank( item_id )
end

function CMD.add_items(itemIds,nums)
	for k,v in pairs(itemIds) do
		CMD.add_templet_item(v,nums[k])
	end
end

function CMD.add_item_list( item_list , num )
	if not num then 
		num = 1
	end
	if num == 0 then return end
	for _,v in pairs(item_list) do
		CMD.add_templet_item(v.item_id,v.num * num )
	end
end

--use item
function CMD.do_use_item( item_config )
	local add_hp = item_config.AddHp
	local add_atk_speed_time = item_config.AddAtkSpeedTime
	local lock_time = item_config.LockTime
	local shadow_time = item_config.ShadowTime
	local add_nimbus = item_config.AddNimbus
	local add_rune = item_config.AddRune
	local add_exp = item_config.AddExp

	if add_hp and add_hp >0 then 
		user.CMD.add_hp( add_hp )
	end
	if add_atk_speed_time and add_atk_speed_time > 0 then 
		user.CMD.add_atk_speed( add_atk_speed_time )
	end
	if lock_time and lock_time > 0 then 
		user.CMD.add_lock( lock_time )
	end
	if shadow_time and shadow_time > 0 then 
		user.CMD.add_shadow( shadow_time )
	end
	if add_nimbus and add_nimbus > 0 then
		CMD.add_nimbus( add_nimbus )
		user.send_request('sync_use_nimbus_item', { add_nimbus = add_nimbus } )
	end
	if add_rune and add_rune > 0 then
		CMD.add_rune( add_rune )
	end	
	if add_exp and add_exp > 0 then
		user.CMD.add_role_exp( add_exp )
	end
end

local function check_item_type_cd( type, nowtime )
	if not use_item_expire_tbl then return end
	local expire_time = use_item_expire_tbl[type]
	if not expire_time then return end
	if expire_time < nowtime then return end
	return true
end

local function record_type_expire_time( type, expire_time )
	if not use_item_expire_tbl then
		use_item_expire_tbl = {}
	end
	use_item_expire_tbl[type] = expire_time
	user.send_request("sync_item_use_expire_time",{ type=type, expire_time=expire_time })
end

local function check_can_attr( config , attr )
	local can_attr = config.CanAttr   --最低位表示  是否可使用;次低位表示 是否可赠送
	if attr == 1 then
    	return (can_attr & 0x01) == 1
   	end 
	if attr == 2 then
		return (can_attr >> 1) == 1
	end
end

function RPC.use_item( args )
	local item_id = args.item_id
	if not item_id then 
		syslog.warn("use_item item_id is nil : ",user.account)
		return 
	end
	local item_config = get_item_config(item_id)
	if not item_config then
		syslog.warn("use_item item_id error : ",user.account,item_id)
		return
	end
	if not check_can_attr( item_config, 1 ) and not user.map then
		syslog.warn("use_item item_id not use: ",user.account,item_id)
		return 
	end
	local nowtime = math.floor(skynet.time())
	local item_type = item_config.ItemType
	local cd = item_config.UseInterval
	if cd and cd > 0 and check_item_type_cd( item_type, nowtime ) then 
		user.send_request( 'send_error_id', { error_id = constant.ITEM_AT_CD } )
		-- syslog.warn("use_item item_id at cd : ",user.account,item_id)
		return 
	end
	if not CMD.try_remove_templet_item( item_id, 1 ) then
		syslog.warn("use_item item_id not enought : ",user.account,item_id)
		return
	end
	if cd and cd > 0 then 
		record_type_expire_time( item_type, nowtime + cd )
	end
	assert(CMD.remove_templet_item( item_id, 1 ))
	CMD.do_use_item( item_config )
	return { item_id=item_id, num=1 }
end

local function do_give_item( target_id, item_id, num )
	local give_info = {
		['item_info'] = {
			item_id = item_id,
			num = num,
		},
		['role_name'] = user.character.general.nickname,
	}
	skynet.call( friendserver, 'lua', 'give_item2target',target_id, give_info )
end

function RPC.give_item( args )
	local target_name = args.target_name
	local item_id = args.item_id
	local num = args.num or 1

	if not item_id or not target_name then 
		syslog.warn("give_item param error : ",user.account)
		return 
	end
	
	local item_config = get_item_config(item_id)
	if not item_config then
		syslog.warn("give_item item_id error : ",user.account,item_id)
		return
	end
	if not check_can_attr( item_config, 2 ) then
		syslog.warn("give_item item_id not give : ",user.account,item_id)
		return 
	end
	if not CMD.try_remove_templet_item( item_id, num ) then
		syslog.warn("give_item item_id not enought : ",user.account,item_id,num)
		return
	end

	local target_id = skynet.call( nameserver, "lua", "name2id", target_name )
    if not target_id then
        user.send_request( "send_error_id", {error_id=constant.ROLE_NOT_EXIST})
        return
    end
	if target_id == user.account then 
        syslog.warnf("give_item not send self %s:",user.account)
        return 
    end
	CMD.remove_templet_item( item_id, num )
	do_give_item( target_id, item_id, num )
end

function CMD.do_reward( addRune,addNimbus,items,multiple)
	if multiple then
		multiple = math.floor(multiple)
	end 
	if addRune and addRune > 0 then 
		CMD.add_rune(addRune)
	end
	if addNimbus and addNimbus > 0 then
		CMD.add_nimbus(addNimbus)
	end
	if items then
		CMD.add_item_list(items,multiple)
	end
end

function CMD.receive_give_item( give_info )
	CMD.add_item_list( {give_info.item_info} )
    user.send_request("sync_give_item", { role_name = give_info.role_name,item_info = give_info.item_info } )
end

return handler
