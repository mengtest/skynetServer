local skynet = require "skynet"
-- local sharedata = require "skynet.sharedata"

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
local shopConfig


handler:init (function (u)
	user = u
    database = skynet.queryservice ("database")
end)

handler:login_init (function ()
    shopConfig = skynet.call (database, "lua", "gameconfig", "get_shop_config")
    user.send_request( "sync_shop_config", {shop_config=shopConfig} ) 
end)

local function get_shop_config( product_id )
    for _,v in pairs( shopConfig ) do
        if v.ProductId == product_id then
            return v
        end
    end
end

local function generate_shop_list()
    local shop_list = {}
    for _,v in ipairs(shopConfig) do
        table.insert(shop_list,{
            shop_id = v.ProductId,
        })
    end
    return shop_list
end

function RPC.get_shop_list()
    return {shop_list = generate_shop_list()}
end

function RPC.buy_shop_item( args )
    local product_id =  args.product_id
    local num = args.num or 1

    if not product_id then
        syslog.warnf("buy_shop_item product_id error %s:",user.account)
        return
    end

    if num >= 600 or num < 0 then
        syslog.warnf("buy_shop_item num error %s %d:",user.account,num)
        return
    end
    local shop_config = get_shop_config(product_id)
    if not shop_config then
        syslog.warnf("buy_shop_item product_id not exist %s %d:",user.account,product_id)
        return
    end
    if shop_config.NeedVipLevel and shop_config.NeedVipLevel > user.character.vip then
        syslog.warnf("buy_shop_item vip not enought %s %d:",user.account,product_id)
        return
    end

    local costNimbus = (shop_config.CostNimbus or 0) * num
    local costRune = (shop_config.CostRune or 0) * num

    if user.character.nimbus < costNimbus or user.character.rune < costRune then
        syslog.warnf("buy_shop_item product_id nimbus or rune not enought %s:",user.account)
        return
    end
    
    if costNimbus > 0 then
        user.CMD.add_nimbus(-costNimbus)
    end
    if costRune > 0 then
        user.CMD.add_rune(-costRune)
    end

    local items = shop_config.ItemIds
    if items then
        user.CMD.add_item_list( items, num )
    end
    return {product_id=product_id,num=num}
end

return handler

