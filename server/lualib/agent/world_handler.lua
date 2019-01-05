local skynet = require "skynet"
-- local sharedata = require "skynet.sharedata"

local syslog = require "syslog"
local handler = require "agent.handler"
local dbpacker = require "db.packer"

local RPC = {}
local CMD = {}
handler = handler.new (RPC, CMD)

local user
local database
local chatserver

handler:init (function (u)
	user = u
    database = skynet.queryservice ("database")
	chatserver = skynet.queryservice ("chat_server")
end)

local FlagOffline = 0
local FlagOnline = 1
function RPC.rpc_world_account_list ()
    
end

return handler

