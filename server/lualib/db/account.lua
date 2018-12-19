local constant = require "constant"
local srp = require "srp"
local crypt = require "skynet.crypt"
local uuid = require "uuid"
local bson = require "bson"
local gameconfig = require"db.gameconfig"
local syslog = require "syslog"
local assert = syslog.assert

local CMD = {}
local connection_handler

function CMD.init (ch)
	connection_handler = ch
	math.randomseed (os.time())
end

local function make_key (account)
	return connection_handler (account)
end

function CMD.cmd_account_load_by_account(account)
	print("-----------cmd_account_load_by_account---------")
	local  mongodb = make_key(account)
	local ret = mongodb.Account:find({Account = account})

	local acc = { account = account }
	if ret then
		if ret:hasNext() then
			assert(ret:count() == 1)
			local ac = ret:next()
			acc.id = ac.ID
			acc.salt = crypt.base64decode(ac.Salt)
			acc.verifier = crypt.base64decode(ac.Verifier)
		else
			acc.salt, acc.verifier = srp.create_verifier (account, constant.default_password)
		end
	end

	return acc
end

function CMD.cmd_account_create (id, account, password, nickname, ip)
	print('----------------cmd_account_create',id , account , password)
	assert (id and account and password, "cmd_account_create invalid argument")
	local salt, verifier = srp.create_verifier (account, password)

	-- 账号表
	local  mongodb = make_key(account)

	local ret = mongodb.Account:safe_insert({ID = id, Account = account,Password = password, Salt = crypt.base64encode(salt),Verifier = crypt.base64encode(verifier), RegisterIp = ip, RegisterDate = bson.date(os.time()), LastLogonIp = ip})
	assert(ret)
	-- print("type:"..type(ret))

	-- 角色信息表
	ret = mongodb.RoleInfo:safe_insert({ID = id, ServerID = 1, NickName = nickname,FirstLogin = true, LastLogoutTime=os.time() })
	assert(ret)

	return id
end

function CMD.loadlist ()
    connection, key = make_list_key ()
    return connection:smembers (key) or {}
end

function CMD.cmd_account_loadInfo( id )
	local info
	local mongodb = make_key(id)

	local ret = mongodb.Account:find({ID = id})

	if ret and ret:hasNext() then
		assert(ret:count() == 1)
	end

	ret = mongodb.RoleInfo:find({ID = id})

	if ret and ret:hasNext() then
		assert(ret:count() == 1)
		local roleInfo = ret:next()
		info = roleInfo or {}
	end
	
	assert(info)
	return info
end

-- function CMD.load_role_info()
-- 	local role_info_table = {}
-- 	local mongodb = make_key(1)
-- 	local ret = mongodb.RoleInfo:find({},{['ID']=1,['_id']=0,['NickName']=1})
-- 	if ret then
-- 		while ret:hasNext() do
-- 			local info = ret:next()
-- 			table.insert( role_info_table, info )
-- 		end
-- 	end
-- 	return role_info_table
-- end

function CMD.GetUserId( account, password )
	local mongodb = make_key(account)
	local ret = mongodb.Account:find({Account = account})
	local id
	if ret and ret:hasNext() then
		assert(ret:count() == 1)
		local ac = ret:next()
		id = ac.ID
	end
	return id
end

-- function CMD.cmd_user_center_loadInfo(args, ip)
-- 	assert(args.userId and args.nickName and args.accounts)
	
-- 	local mongodb = make_key(args.userId)

-- 	local ret = mongodb.Account:find({ID = args.userId})

-- 	local info
-- 	if ret and ret:hasNext() then
-- 		info = CMD.cmd_account_password_loadInfo(args.accounts, "666666")
-- 	else
-- 		if not args.headImgUrl then
-- 			args.headImgUrl = ""
-- 		end

-- 		CMD.cmd_account_create(args.userId, args.accounts, "666666", args.nickName, args.headImgUrl, ip)
-- 		info = CMD.cmd_account_password_loadInfo(args.accounts, "666666")
-- 	end

-- 	return info
-- end

function CMD.cmd_account_saveInfo( account, json )
    -- local connection, key = make_accInfo_key (account)
    -- assert (connection:set (key, json) ~= 0, "saveInfo failed")
    return true
end

return CMD
