local skynet = require "skynet"
-- local socket = require "socket"
local socket = require "skynet.socket"
local syslog = require "syslog"
local httpd = require "http.httpd"
local dbpacker = require "db.packer"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local uuid = require "uuid"
local json = require "json.json"
local inspect = require 'preload.inspect'

local table = table
local string = string
local CMD = {}

local slaveCount,webserver = ...
local AuthCode = {}
local AuthCodeExpireTime = 3 * 60 * 100

local database

skynet.init(function()
    database = skynet.queryservice ("database")
end)

local function hash_str (str)
    local hash = 0
    string.gsub (str, "(%w)", function (c)
        hash = hash + string.byte (c)
    end)
    return hash
end

local function hash_num (num)
    local hash = num << 8
    return hash
end
  
local function getHandler(key)
    local hash
    local t = type (key)
    if t == "string" then
        hash = hash_str (key)
    else
        hash = hash_num (assert (tonumber (key)))
    end
    return math.ceil(hash % slaveCount + 1)
end

local function response(id, ...)
    local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
    if not ok then
        -- if err == sockethelper.socket_error , that means socket closed.
        skynet.error(string.format("fd = %d, %s", id, err))
    end
end

local function recordAuthCode( info )
    print('------------------recordAuthCode')
    local account = info.account
    if not account or not info.authCode then 
        return -9
    end
    return skynet.call(webserver, 'lua', 'TransmitDoRecordAuthCode', getHandler(account), info)
end

local function creatAccount( info )
    print('------------------creatAccount')
    local account = info.account
    if not (account and info.password and info.authCode) then 
        return -9
    end
    local result,info = skynet.call('.webclient', 'lua', 'request',
        "https://webapi.sms.mob.com/sms/verify",nil,{appkey='296be7aa83ed8',phone=18668067789,zone=86,code=1234})
    local content = json.decode(info)
    if content.error then
        print(inspect(content))
    end
    -- local _,status= info:match "\"(.*)\":%s*(.*),"
    return content.status
    -- return skynet.call(webserver, 'lua', 'TransmitDoCreatAccount', getHandler(account), info)
end

local function rolePay( info )
    print('------------------rolePay')
    return 0
end

function CMD.DoRecordAuthCode( info )
    AuthCode[info.account] = info.authCode
    skynet.timeout (AuthCodeExpireTime, function ()
        if AuthCode[account] then
            AuthCode[account] = nil
        end
    end)
    return 0
end

function CMD.DoCreatAccount( info )
    local account = info.account
    local authMoCode = AuthCode[account]
    if authMoCode and authMoCode == info.authCode then
        local roleId = uuid.gen ()
        local id = skynet.call(database,'lua','account','cmd_account_create',roleId, account, info.password, nickname, ip)
        if not id then
            return -1
        end
        AuthCode[account] = nil
    else
        return -2
    end
    return 0
end


function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat webserver")
end

function CMD.web( id )
    socket.start(id)
    -- limit request body size to 8192 (you can pass nil to unlimit)
    local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
    if code then
        if code ~= 200 then
            response(id, code)
        else
            local ret = -1
            local tmp = {}
            if header.host then
                -- table.insert(tmp, string.format("host: %s", header.host))
            end
            local path, query = urllib.parse(url)
            -- table.insert(tmp, string.format("path: %s", path))
            if query then
                local q = urllib.parse_query(query)
                if path =='/createAccount' then
                    ret = creatAccount(q)
                elseif path == '/authCode' then
                    ret = recordAuthCode(q)
                elseif path == '/pay' then
                    ret = rolePay(q)
                end
            end
            -- table.insert(tmp, "-----header----")
            -- for k,v in pairs(header) do
            --     table.insert(tmp, string.format("%s = %s",k,v))
            -- end
            -- table.insert(tmp, "-----body----\n" .. body.."\n")

            -- test load data from database
            -- local allList = skynet.call(database, "lua", "account", "loadlist")
            local json = dbpacker.pack(ret)
            table.insert(tmp, "-----ret data----\n" .. json.."\n")
            response(id, code, table.concat(tmp,"\n"))
        end
    else
        if url == sockethelper.socket_error then
            skynet.error("socket closed")
        else
            skynet.error(url)
        end
    end
    socket.close(id)
end

local traceback = debug.traceback
skynet.start(function()
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)
    skynet.dispatch("lua", function (_,_,command,...)
       local f = CMD[command]
        if not f then
            syslog.warnf ("unhandled web slave message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, ...)
        if not ok then
            syslog.warnf ("handle  web slave message(%s) failed : %s", command, ret)
            -- kick_self ()
            return skynet.ret ()
        end
        skynet.retpack (ret) 
    end)
end)

