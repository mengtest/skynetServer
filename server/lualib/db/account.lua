local constant = require "constant"
local srp = require "srp"
local crypt = require "skynet.crypt"
local uuid = require "uuid"
local bson = require "bson"
local gameconfig = require"db.gameconfig"
local syslog = require "syslog"
local assert = syslog.assert
local table_insert = table.insert

local CMD = {}
local connection_handler

function CMD.init (ch)
	connection_handler = ch
	math.randomseed (os.time())
end

local function make_key (account)
	return connection_handler (account)
end

function CMD.ChangePassward(account, password)
	local mongodb = make_key(account)
    return mongodb.Account:safe_update({Account = account},{["$set"] = {Password = password}})    
end

function CMD.cmd_account_create (id, account, password, nickname, sex)
	print('----------------cmd_account_create',id , account , password)
	assert (id and account and password, "cmd_account_create invalid argument")
	local salt, verifier = srp.create_verifier (account, password)

	-- 账号表
	local  mongodb = make_key(account)

	local ret = mongodb.Account:safe_insert({ID = id, Account = account,Password = password, Status=1, RegisterDate = bson.date(os.time())})
	assert(ret)
	-- 角色信息表
	ret = mongodb.RoleInfo:safe_insert({ID = id, ServerID = 1, NickName = nickname,FirstLogin = true, LastLogoutTime=os.time(),Sex = sex})
	assert(ret)
	return id
end


function CMD.cmd_account_loadInfo( id )
	local mongodb = make_key(id)
	local ret = mongodb.Account:findOne({ID = id},{['_id']=0})
	if not ret then return end
	ret = mongodb.RoleInfo:findOne({ID = id},{['_id']=0})
	assert(ret)
	return ret
end

function CMD.GetPayInfo( account )
	local mongodb = make_key(account)
	local info = mongodb.PayInfo:findOne({ID = account},{['_id']=0,['ID']=0})
	return info and info.PayInfo or {}
end

function CMD.SavePayInfo( account, grade, term)
	local mongodb = make_key(account)
	local ret = mongodb.PayInfo:findOne({ID = account,['PayInfo.grade'] = grade, ['PayInfo.term'] = term})
    if not ret then
        return mongodb.PayInfo:safe_update({ID = account},{["$push"] = {PayInfo = {grade=grade,term=term}}},true)
    else
        return mongodb.PayInfo:safe_update({ID = account,['PayInfo.grade'] = grade, ['PayInfo.term'] = term},{["$set"] = {['PayInfo.$'] = {grade=grade,term=term}}},true)
    end
end


function CMD.GetUserId( account )
	local mongodb = make_key(account)
	local ret = mongodb.Account:find({Account = account},{['_id']=0})
	if ret and ret:hasNext() then
		assert(ret:count() == 1)
		local ac = ret:next()
		return ac.ID
	end
end

function CMD.AuthPassword( account, password )
	local mongodb = make_key(account)
	local ret = mongodb.Account:find({Account = account},{['_id']=0})
	if ret and ret:hasNext() then
		assert(ret:count() == 1)
		local ac = ret:next()
		if ac.Password ~= password then return end
		return ac.ID
	end
end

function CMD.cmd_account_saveInfo( account, json )
    -- local connection, key = make_accInfo_key (account)
    -- assert (connection:set (key, json) ~= 0, "saveInfo failed")
    return true
end

return CMD