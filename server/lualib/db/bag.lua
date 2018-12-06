local bag = {}
local connection_handler

local function make_key (account)
	return connection_handler (account)
end

function bag.init (ch)
    connection_handler = ch
end

function bag.save_item( account , bags )
	local mongodb = make_key(account)
	local ret = mongodb.Bags:find({ID = account})
	if not ret:hasNext() then
		mongodb.Bags:safe_insert({ID = account})
	end
    return mongodb.Bags:safe_update({ID = account},{["$set"] = {ItemList = bags}})    
end

return bag
