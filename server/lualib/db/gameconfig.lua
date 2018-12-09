
local syslog = require "syslog"
local assert = syslog.assert

local CMD = {}
local connection_handler

local learnConfig

-- local function str2table(str)
--     if str == nil or type(str) ~= "string" then
--         return
--     end
--     return load("return " .. str)()
-- end

local function make_key (account)
	return connection_handler (account)
end


local function loadAllLearnConfig()
	local mongodb = make_key(1)
	local ret = mongodb.LearnConfig:find()
	learnConfig = {}
	if ret then
		while ret:hasNext() do
            local info = ret:next()
            table.insert(learnConfig, info)
		end
	end
	assert(next(learnConfig))
end

local function load_config()
	-- loadAllLearnConfig()
end

function CMD.init (ch)
	connection_handler = ch
	load_config()
end

function CMD.GetLearnConfig()
	return learnConfig
end

return CMD