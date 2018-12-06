local host = "127.0.0.1"
local port = 27017
local db_name = 'study'

local center = {
	host = host,
	port = port,
	db_name = db_name,
}


local ngroup = 20
local group = {}

for i = 1, ngroup do
	table.insert ( group, { host = host, port = port } )
end

local database_config = { center = center, group = group }

return database_config
