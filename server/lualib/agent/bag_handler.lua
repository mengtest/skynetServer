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

handler:login_init (function ()
	
end)

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

function CMD.remove_templet_item( item_id , num )
	
end

function CMD.get_bags()
	clean_bags()
	return bags
end

local function sync_score()
	user.send_request("update_score", {nimbus = user.character.nimbus,rune = user.character.rune} )
end

function CMD.add_templet_item( item_id , num )
	
end

function CMD.add_items(itemIds,nums)
	
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

end


function RPC.use_item( args )
	
end

return handler
