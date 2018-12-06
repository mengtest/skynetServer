local gamelog = {}
local connection_handler

local function make_key (account)
	return connection_handler (account)
end

function gamelog.init (ch)
    connection_handler = ch
end

function gamelog.save_item_change_log( account, itemid, num ,type )
	local mongodb = make_key(account)
	local time = os.date()
	local log = string.format()
    return mongodb.ItemChangLog:safe_update({ID = account},{["$push"] = {Log=log}}, true )    
end

function gamelog.save_rune_change_log( account, rune ,addRune, type )
	local mongodb = make_key(account)
	local time = os.date()
	local log = string.format('role %s, %s,%s, %s, %s',account, rune ,addRune, type,time)
    return mongodb.RuneChangLog:safe_update({ID = account},{["$push"] = {Log=log}}, true )    
end

function gamelog.save_nimbus_change_log( account, nimbus, addNimbus ,type )
	local mongodb = make_key(account)
	local time = os.date()
	local log = string.format()
    return mongodb.NimbusChangLog:safe_update({ID = account},{["$push"] = {Log=log}}, true )    
end

function gamelog.save_enter_map_log( account, mapId, isEnter )
	local mongodb = make_key(account)
	local time = os.date()
	local log = string.format()
    return mongodb.MapLog:safe_update({ID = account},{["$push"] = {Log=log}}, true )    
end

function gamelog.save_Level_change_log( account, level , addLevel, type )
	local mongodb = make_key(account)
	local time = os.date()
	local log = string.format()
    return mongodb.ChangeLevelLog:safe_update({ID = account},{["$push"] = {Log=log}}, true )    
end

return gamelog
