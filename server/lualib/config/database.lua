local host = "127.0.0.1"
local port = 6379
local db = 0

local center = {
	host = host,
	port = port,
	db = db,
}

local ngroup = 0
local group = {}
-- for i = 1, ngroup do
-- 	table.insert (group, { host = host, port = port + i, db = db })
-- end

table.insert (group, { host = host, port = port , db = db })


local database_config = { center = center, group = group }

return database_config
