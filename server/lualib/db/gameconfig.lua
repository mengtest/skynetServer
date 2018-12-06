
local syslog = require "syslog"
local assert = syslog.assert

local CMD = {}
local connection_handler

local itemConfig
local shopConfig

-- local function str2table(str)
--     if str == nil or type(str) ~= "string" then
--         return
--     end
--     return load("return " .. str)()
-- end

local function make_key (account)
	return connection_handler (account)
end

local function load_item_config()
	-- local mongodb = make_key(1)
	-- local ret = mongodb.ItemConfig:find()
	-- itemConfig = {}
	-- if ret then
	-- 	while ret:hasNext() do
 --            local item = ret:next()
 --            table.insert(itemConfig, item)
	-- 	end
	-- end
	-- assert(next(itemConfig),'itemConfig config error')
end

local function load_shop_config()
	-- local mongodb = make_key(2)
	-- local ret = mongodb.ShopConfig:find()
	-- shopConfig = {}
	-- if ret then
	-- 	while ret:hasNext() do
 --            local shop = ret:next()
 --            table.insert(shopConfig, shop)
	-- 	end
	-- end
	-- assert(next(shopConfig),'shopConfig config error')
end

local function load_config()
	load_item_config()
	load_shop_config()
end

function CMD.init (ch)
	connection_handler = ch
	-- mongodb = mg
	load_config()
end

function CMD.get_item_config()
	return itemConfig
end

function CMD.get_shop_config()
	return shopConfig
end

return CMD