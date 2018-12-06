package.cpath = package.cpath .. ";../3rd/skynet/luaclib/?.so;../server/luaclib/?.so;../3rd/zbstudio/?.so"
package.path = package.path .. ";../3rd/skynet/lualib/?.lua;../common/?.lua;../3rd/zbstudio/?.lua"


--local print_r = require "common.dump"
local socket = require "client.socket"
local sproto = require "sproto"
local srp = require "srp"
local aes = require "aes"
local login_proto = require "proto.login_proto"
local game_proto = require "proto.game_proto"
local constant = require "constant"
local mobdebug = require "mobdebug"
local dump = require "dump"


local useraccount = arg[1]
local password = arg[2]

local user = { account = arg[1], password = arg[2] }

if not user.account then
	local f = io.open ("anonymous", "r")
	if not f then
		f = io.open ("anonymous", "w")
		local name = ""
		math.randomseed (os.time ())
		for i = 1, 16 do
			name = name .. string.char (math.random (127))
		end

		user.account = name
		f:write (name)
		f:flush ()
		f:close ()
	else
		user.account = f:read ("a")
		f:close ()
	end
end

if not user.password then
	user.password = constant.default_password
end

local server = "192.168.120.81"
local login_port = 9777
local game_port = 9555
local gameserver = {
	addr = "192.168.120.81",
	port = 9555,
	name = "gameserver",
}

local host = sproto.new (login_proto.s2c):host "package"
local request = host:attach (sproto.new (login_proto.c2s))
local fd 
local game_fd

local function send_message (fd, msg)
    -- for i = 1, #msg do 
    --     print(string.format("msg:%d %d", i, string.byte(msg, i)))
    -- end
	local package = string.pack (">s2", msg)
	socket.send (fd, package)

	--local unpackge, size = string.unpack(">s2", package)
	-- for i = 1, #unpackge do 
    --     print(string.format("unpackge:%d %d", i, string.byte(unpackge, i)))
    -- end
end

local session = {}
local session_id = 0
local function send_request (name, args)
	print ("send_request", name)
	session_id = session_id + 1
	local str = request (name, args, session_id) -- 转化为sproto的字符串
	send_message (fd, str) 
	print ("session_id::", session_id)
	-- print ("send_message args size:", #str)

    -- for i = 1, #str do 
    --     print(string.format("send_message:%d %d", i, string.byte(str, i)))
    -- end
	-- print ("send_message args str:", str)
	session[session_id] = { name = name, args = args } -- 保存上行数据，下行时检查
end

local function unpack (text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte (1) * 256 + text:byte (2)
    print("--- unpack size:", size, s)--- s    201 199

	if size < s + 2 then
		return nil, text
	end

	return text:sub (3, 2 + s), text:sub (3 + s)
end

local function recv (last)
	local result
	result, last = unpack (last)
	if result then
		return result, last
	end
	local r = socket.recv (fd)
	if not r then
		return nil, last
	end
	if r == "" then
		error (string.format ("socket %d closed", fd))
	end

	return unpack (last .. r)
end

-- local rr = { wantmore = true }
local rr = { wantmore = true, myStr = "hello world" }
local function handle_request (name, args, response) -- 处理服务端的请求
    print ("^^^@ handle_request request from server", name)
    
	if args then
		dump(args,"-------------------" .. name or "nil")

		if name == "client_user_info" then
			user.id = args.ID
			--print("client_user_info id"..user.id)
		end

		if name == "map_list" then
			for m, k in pairs(args.map) do
				print("id:"..k.id)
				print("name:"..k.name)
				print("level:"..k.level)
				print("nimbus:"..k.nimbus)
				print("radius:"..k.radius)
				-- print(type(k.box))
				print("bbox:"..k.bbox.left)
				print("bbox:"..k.bbox.bottom)
				print("bbox:"..k.bbox.right)
				print("bbox:"..k.bbox.top)
				-- for x, y in pairs(k.box) do
				-- 	print("x:"..x)
				-- 	print("bbox:"..y)
				-- end
			end
		end
		
		if name == "aoi_add" then
			print ("---------------------- aoi_add character:"..args.character.id)
			print ("---------------------- aoi_add character:"..args.character.general.nickname)
			-- local re = { wantmore = true }
			-- print(type(response))
			-- send_message (fd, response (re))
			-- send_message (fd, response (rr)) -- rr是返回给服务端的数据
		end

		if name == "aoi_remove" then
			print ("---------------------- aoi_remove character:"..args.character)
		end
		
		if name == "aoi_update_move" then
			print ("---------------------- aoi_update_move character:"..args.character.id)
			print ("---------------------- aoi_update_move character:"..args.character.movement.pos.x)
			print ("---------------------- aoi_update_move character:"..args.character.movement.pos.y)
			-- send_message (fd, response (rr)) -- rr是返回给服务端的数据
		end
	else
		print "empty argument"
	end

	-- if name:sub (1, 3) == "aoi" and  name ~= "aoi_remove" then
	-- 	if response then
    --         print ("--- response to server", name)
	-- 		send_message (fd, response (rr)) -- rr是返回给服务端的数据
	-- 	end
	-- end
end

local RESPONSE = {}

function RESPONSE:logintest (args)
	fd = assert (socket.connect (args.ip, args.port))
	user.session = args.session
	send_request ("login", { session = user.session, token = args.token })

	host = sproto.new (game_proto.s2c):host "package"
	request = host:attach (sproto.new (game_proto.c2s))
end

function RESPONSE:handshake (args)
	print ("RESPONSE.handshake")
	local name = useraccount
	assert (useraccount == user.account)

	if args.user_exists then
		local key = srp.create_client_session_key (name, user.password, args.salt, user.private_key, user.public_key, args.server_pub)
		print ("name:"..name)
		print ("user.password:"..user.password)
		print ("args.salt:"..args.salt)
    -- for i = 1, #key do 
    --     print(string.format("key:%d %d", i, string.byte(key, i)))
    -- end
		user.session_key = key
		local ret = { challenge = aes.encrypt (args.challenge, key) }
		send_request ("auth", ret)
	else
		print (name, constant.default_password)
		local key = srp.create_client_session_key (name, constant.default_password, args.salt, user.private_key, user.public_key, args.server_pub)
		user.session_key = key
		local ret = { challenge = aes.encrypt (args.challenge, key), password = aes.encrypt (user.password, key) }
		send_request ("auth", ret)
	end
end

function RESPONSE:auth (args)
	print ("RESPONSE.auth")

	user.session = args.session
	local challenge = aes.encrypt (args.challenge, user.session_key)
	send_request ("challenge", { session = args.session, challenge = challenge })
end

function RESPONSE:challenge (args)
	print ("RESPONSE.challenge")
	print ("RESPONSE.challenge gameserver ip:"..args.ip)
	print ("RESPONSE.challenge gameserver port:"..args.port)

	local token = aes.encrypt (args.token, user.session_key)

	fd = assert (socket.connect (args.ip, args.port))
	-- fd = assert (socket.connect (gameserver.addr, gameserver.port))
	print (string.format ("game server connected, fd = %d", fd))
	send_request ("login", { session = user.session, token = token })

	host = sproto.new (game_proto.s2c):host "package"
	request = host:attach (sproto.new (game_proto.c2s))

end

local function handle_response (id, args)
	local s = assert (session[id])
	session[id] = nil
	local f = RESPONSE[s.name] -- 检查是否有这个方法, 比如一个上行：send_request ("auth", ret), session[id]则会从上行保存的记录中，查找是否有这次会话，有则检查是否在 RESPONSE响应表 中有auth这个方法，有则执行

    print ("^^^# response from server", s.name)

	if f then
        print "--- have func"
		f (s.args, args)
	else
		dump(args,"-----------response")
	end
end

local function handle_message (t, ...)
	if t == "REQUEST" then
		handle_request (...) -- 处理服务端的请求
	else
		handle_response (...) -- 处理请求服务端后的响应（服务端返回）
	end
end

local last = ""
local function dispatch_message ()
	while true do
		local v
		v, last = recv (last)
		if not v then
			break
		end

		handle_message (host:dispatch (v)) -- sproto解析来自服务端的数据（服务端也是用sproto编码，所以这里用它解码）
	end
end

local private_key, public_key = srp.create_client_key ()
	-- for i = 1, #private_key do 
    --     print(string.format("private_key:%d,", string.byte(private_key, i)))
	-- end
	-- for i = 1, #public_key do 
    --     print(string.format("public_key:%d,", string.byte(public_key, i)))
	-- end

-- print("N:"..N)
--local str
-- 	for i = 1, #N do 
-- 		--str = str + tostring(string.byte(N, i))
--         -- print(string.format("N:%d %d", i, string.byte(N, i)))
--         print(string.format("%d,", string.byte(N, i)))
-- 	end
-- 	print(str)
-- print("G:"..G)
-- for i = 1, #G do 
-- 	print(string.format("N:%d %d", i, string.byte(G, i)))
-- end
user.private_key = private_key
user.public_key = public_key 
fd = assert (socket.connect (server, login_port))
print (string.format ("login server connected, fd = %d", fd))
-- send_request ("handshake", { account = user.account, client_pub = public_key })
send_request ("logintest", { account = user.account, password = user.password })

local HELP = {}

--[[
lua client.lua aaa bbb
-- id:3149323469594823681

lua client.lua ccc ddd
-- id:3149323469594823681

cd client
./run
character_create character = { name = "yang", race = "human", class = "warrior" }
character_pick id = 3148166985225864193
map_ready
move pos = { x = 123, z = 321 }
combat target = 7
test1
]]

local mycmd = {}
mycmd[1] = { character = { name = "yang", race = "human", class = "warrior" } }
mycmd[11] = { character = { name = "xuan", race = "human", class = "warrior" } }
mycmd[2] = { }
mycmd[3] = { id = 3149323469594823681 }
mycmd[13] = { id = 3149323823929624577 }
mycmd[4] = { }
mycmd[5] = { pos = { x = 123, z = 321 }}
mycmd[15] = { pos = { x = 129, z = 329 }}
mycmd[6] = { pos = { x = 120, z = 310 }}
mycmd[16] = { pos = { x = 0, z = 10 }}
mycmd[7] = { target = 7 }
mycmd[8] = { arg1 = 456, arg2 = "aaa"}

function CmdParser( cmdStr )
    -- body
    local strTab = {}
    local rets = string.gmatch(cmdStr, "%S+")
    for i in (rets) do
        table.insert(strTab, i)
    end
    local argTab = {}
	local cmd = strTab[1]
	print("CmdParser:".. cmd or "nil")

 --    if cmd == "world" then
 --        cmd = "character_enter_world"

 --    elseif cmd == "pick" then
 --        cmd = "character_pick"
	-- 	argTab = { mapid = tonumber(strTab[2]) }
		
	-- elseif cmd == "leave" then
	-- 	cmd = "character_leave"

 --    elseif cmd == "move" then
 --        argTab = {
 --            pos = {
 --                x = tonumber(strTab[2]),
	-- 			y = tonumber(strTab[3]),
 --            }
 --        }

 --    elseif cmd == "enter" then
 --        cmd = "map_ready"
 --    elseif cmd == "atk" then
 --        cmd = "combat"
	-- 	argTab = { target = tonumber(strTab[2]) }
	-- elseif cmd == "matk" then
	-- 	cmd = "combat_monster"
	-- 	argTab = {monster_id = tonumber(strTab[2]), target = user.id, skill_id = tonumber(strTab[3])}
	-- elseif cmd == "re" then
	-- 	cmd = "revive"
	-- elseif cmd == "cm" then
	-- 	cmd = "combat_change_multiple"
	-- 	argTab = {multiple = tonumber(strTab[2])}
	-- elseif cmd == "c" then
	-- 	cmd = "rpc_send_world_chat_message"
	-- 	argTab = { message = strTab[2] or "nil" }
	-- elseif cmd == "a" then
	-- 	cmd = "rpc_apply_add_friend"
	-- 	argTab = { be_apply_id = strTab[2] }
	-- elseif cmd == "g" then
	-- 	cmd = "rpc_server_friend_list"
	-- elseif cmd == "agree" then
	-- 	cmd = "rpc_confirm_add_friend"
	-- 	argTab = {friend_id = tonumber(strTab[2]),flag = 4}
	-- elseif cmd == "rf" then 
	-- 	cmd = "refresh_friend_info"
	-- 	argTab = {friend_id = tonumber(strTab[2])}
	-- elseif cmd == "rm" then
	-- 	cmd = "rpc_del_friend"
	-- 	argTab = {remove_id = tonumber(strTab[2])}
	-- elseif cmd == "pc" then
	-- 	cmd = "rpc_send_target_chat_message"
	-- 	argTab = {target_id = tonumber(strTab[2]) ,message = strTab[3]}
	-- elseif cmd == "mail" then
	-- 	cmd = "role_send_mail"
	-- 	argTab = {target_name = strTab[2] ,title = strTab[3],content = strTab[4],item_list = {
	-- 		{item_id=100001,num=2},{item_id=100001,num=2},{item_id=100002,num=2},
	-- 	}}	
	-- elseif cmd == "look" then
	-- 	cmd = "get_mail_message"
	-- 	argTab = {mail_guid = strTab[2]}
	-- elseif cmd == "del" then
	-- 	cmd = "del_mail"
	-- 	argTab = {mail_guid = strTab[2]}
	-- elseif cmd == "del_all" then
	-- 	cmd = "del_all_mail"
	-- elseif cmd == 'mailitem' then
	-- 	cmd = 'receive_mail_item'
	-- 	argTab = {mail_guid = strTab[2]}
	-- elseif cmd == 'recvall' then
	-- 	cmd = 'receive_all_mail_item'
	-- elseif cmd == "commend" then
	-- 	cmd = "get_commend_friend"
	-- 	argTab = {is_refresh = false}
	-- elseif cmd == "use" then
	-- 	cmd = "use_item"
	-- 	argTab = {item_id = tonumber(strTab[2])}
	-- elseif cmd == "buy" then
	-- 	cmd = "buy_shop_item"
	-- 	argTab = {product_id = tonumber(strTab[2]),num=tonumber(strTab[3])}
	-- elseif cmd == "rank" then
	-- 	cmd = "get_type_rank"
	-- 	argTab = {rank_type = tonumber(strTab[2]),begin_ranking=1,count =10}
	-- elseif cmd == "myrank" then
	-- 	cmd = "get_my_type_rank"
	-- 	argTab = {rank_type = tonumber(strTab[2])}
	-- elseif cmd == "shop" then
	-- 	cmd = "get_shop_list"
	-- elseif cmd == "gm" then
	-- 	cmd = "gm_add_money"
	-- 	argTab = {types = tonumber(strTab[2]),num = tonumber(strTab[3])}
	-- elseif cmd == "role" then
	-- 	cmd = 'get_day_active' 
	-- 	argTab = {id = tonumber(strTab[2])}
	-- elseif cmd == 'rrrr' then
	-- 	cmd = 'get_day_active_reward'
	-- 	argTab = {id = tonumber(strTab[2])}
	-- elseif cmd == 'month' then
	-- 	cmd = 'pay_month_card'
	-- elseif cmd == 'more' then
	-- 	cmd = 'receive_card_reward'
	-- elseif cmd == 'give' then
	-- 	cmd = 'give_item'
	-- 	argTab = {target_name = strTab[2],item_id = tonumber(strTab[3]),num = tonumber(strTab[4])}
	-- elseif cmd == 'sign' then
	-- 	cmd = 'every_day_sign_in'
	-- elseif cmd == 'acc' then
	-- 	cmd = 'receive_accum_sign_in_reward'
	-- 	argTab = {reward_id = tonumber(strTab[2])}
	-- elseif cmd == 'rookie' then
	-- 	cmd = 'receive_rookie_gift'
	-- elseif cmd == 'pay' then
	-- 	cmd = 'pay_vip'
	-- 	argTab = {pay_id = tonumber(strTab[2])}
	-- elseif cmd == 'first' then
	-- 	cmd = 'receive_first_gift'
	-- elseif cmd == 'vip' then
	-- 	cmd = 'receive_vip_reward'
	-- 	argTab = {vip_level = tonumber(strTab[2])}
	-- end

    return cmd, argTab
end

local function handle_cmd (line)
    local cmd, t = CmdParser(line)
	-- local cmd
	-- local p = string.gsub (line, "([%w-_]+)", function (s) 
	-- 	cmd = s
	-- 	return ""
	-- end, 1)
 --    local t = mycmd[tonumber(p)]

    --[[
	print (cmd, "====", p)

	if string.lower (cmd) == "help" then
		for k, v in pairs (HELP) do
			print (string.format ("command:\n\t%s\nparameter:\n%s", k, v()))
		end
		return
	end

    print("--- load type:", type(load))

    local f, err = load (p, "=(load)" , "t", t)

	if not f then error (err) end
	f ()

	print ("----- cmd", cmd)
	if t then
		--print_r (t)
	else
		print ("--- null argument")
	end

	if not next (t) then t = nil end
]]
    if not next (t) then t = nil end

	if cmd then
		local ok, err = pcall (send_request, cmd, t)
		if not ok then
			print (string.format ("invalid command (%s), error (%s)", cmd, err))
		end
	end
end

function HELP.character_create ()
	return [[
	name: your nickname in game
	race: 1(human)/2(orc)
	class: 1(warrior)/2(mage)
]]
end

print ('type "help" to see all available command.')
while true do
	dispatch_message ()
	local cmd = socket.readstdin ()
	if cmd then
		handle_cmd (cmd)
	else
		socket.usleep (100)
	end
end

