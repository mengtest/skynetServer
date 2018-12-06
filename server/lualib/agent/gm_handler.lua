local skynet = require "skynet"
-- local sharedata = require "sharedata"
-- local sharedata = require "skynet.sharedata"
local dbpacker = require "db.packer"

local syslog = require "syslog"
local handler = require "agent.handler"
local dump = require "common.dump"

local RPC = {}
local user
handler = handler.new (RPC)

handler:init (function (u)
	user = u
end)

local function gmExecute( types, num )
	if types == 1 then 
		user.CMD.add_nimbus(num)
	elseif types == 2 then 
		user.CMD.add_rune(num)
	end
end

function RPC.gm_add_money (args)
	local types = args.types
	local num = args.num
    return gmExecute( types, num )

end

return handler

