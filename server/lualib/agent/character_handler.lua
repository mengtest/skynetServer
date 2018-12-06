local skynet = require "skynet"
-- local sharedata = require "skynet.sharedata"

local syslog = require "syslog"
local dbpacker = require "db.packer"
local handler = require "agent.handler"
local uuid = require "uuid"
local dump = require "common.dump"

local RPC = {}
local CMD = {}
handler = handler.new (RPC, CMD)

local user
local database
-- local gdd
local world

handler:init (function (u)
	-- print("//////////////character_handler init/////////////////")
	user = u
	database = skynet.queryservice ("database")
	-- gdd = sharedata.query "gdd"
	world = skynet.queryservice ("world")
end)

-- 进入世界服务器
function RPC.character_enter_world()
	local enter = skynet.call (world, "lua", "cmd_world_character_enter", user.character.id)
	return {enter = enter}
end

function RPC.character_pick (args)
	-- print("//////////////character_handler character_pick/////////////////")
	local mapid = args.mapid
	if not mapid then
		syslog.warn("character_pick param error : ", player_guid )
		return
	end

	local conf = skynet.call (world, "lua", 'get_map_conf', mapid)
	if not conf then
		syslog.warn("character_pick mapid error : ", player_guid, mapid )
		return
	end
	if user.map then
		syslog.warn("character_pick already map : ",user.account,user.map)
		return
	end
	syslog.notice (string.format ("--- REQUEST.character_pick, id:%d mapid:%d", user.character.id, mapid))

	local ok, multiple_min, map_multiple = skynet.call (world, "lua", "cmd_world_character_enter_map", user.character.id, mapid)

	assert(ok)
	user.character.multiple = multiple_min
	user.character.map_multiple = map_multiple
	
	return { character = user.character }
end

function RPC.character_leave()
	local mapid = 0
	if user.map then
		skynet.call (database, "lua", "game", "cmd_game_exp_up", user.character.id, user.character.attribute.exp)
		mapid = skynet.call (user.map, "lua", "cmd_map_character_leave", skynet.self())
	end

	return {map_id = mapid}
end

-- 获取用户列表相关信息
function CMD.cmd_get_user_list_item()
	return {id = user.character.id, face = user.character.face, nickname = user.character.general.nickname, nimbus = user.character.nimbus, multiple = user.character.multiple}
end

return handler

