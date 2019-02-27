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
local helper = require 'common.helper'

local table = table
local string = string
local CMD = {}

local openSDKAuth = false
local slaveCount,webserver = ...
local AppKey='29a32e555cdfa'

local database

skynet.init(function()
    database = skynet.queryservice ("database")
end)

local function response(id, ...)
    local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
    if not ok then
        -- if err == sockethelper.socket_error , that means socket closed.
        skynet.error(string.format("fd = %d, %s", id, err))
    end
end

local function changePassward( args )
    local account = tonumber(args.account)
    local password = args.password
    local authCode = args.authCode

    print("-------------------changePassward",account,password,authCode)
    if not (account and password and authCode) then 
        return -2
    end
    local lenth1 = #password 
    if lenth1 < 6 or lenth1 > 13 then return -2 end

    if not skynet.call(database,'lua','account','GetUserId',account) then
        return -3  --account not exist
    end

    local result,info = skynet.call('.webclient', 'lua', 'request',"https://webapi.sms.mob.com/sms/verify",
        nil,{appkey=AppKey,phone=account,zone=86,code=authCode})
    local content = json.decode(info)
    if openSDKAuth and content.status ~= 200 then
        return content.status
    end
    if not skynet.call(database,'lua','account','ChangePassward',account, password) then
        return -4
    end
    return 0
end

local function creatAccount( args )
    local account = tonumber(args.account)
    local password = args.password
    local nickname = args.nickname
    local authCode = args.authCode
    local sex = tonumber(args.sex)
    print("-------------------creatAccount",account,password,nickname,authCode,sex)
    if not (account and password and nickname and authCode and sex) then 
        return -2
    end

    local lenth0 = helper.get_string_len(account) 
    if lenth0 ~= 11 then return -2 end
    local lenth1 = #password
    if lenth1 < 6 or lenth1 > 13 then return -2 end
    local lenth2 = #nickname
    if lenth2 < 6 or lenth2 > 12 then return -2 end

    if skynet.call(database,'lua','account','GetUserId',account) then
        return -3 --account already exist
    end

    local result,info = skynet.call('.webclient', 'lua', 'request',"https://webapi.sms.mob.com/sms/verify",
        nil,{appkey=AppKey,phone=account,zone=86,code=authCode})
    local content = json.decode(info)
    if openSDKAuth and content.status ~= 200 then
        return content.status
    end
    if not skynet.call(database,'lua','account','cmd_account_create',uuid.gen (), account, password, nickname, sex) then
        return -4
    end
    return 0
    -- local _,status= info:match "\"(.*)\":%s*(.*),"
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
                elseif path == '/changePassward' then
                    ret = changePassward(q)
                end
            end
            -- table.insert(tmp, "-----header----")
            -- for k,v in pairs(header) do
            --     table.insert(tmp, string.format("%s = %s",k,v))
            -- end
            -- table.insert(tmp, "-----body----\n" .. body.."\n")
            local json = dbpacker.pack(ret)
            table.insert(tmp,json)
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



-- local function hash_str (str)
--     local hash = 0
--     string.gsub (str, "(%w)", function (c)
--         hash = hash + string.byte (c)
--     end)
--     return hash
-- end

-- local function hash_num (num)
--     local hash = num << 8
--     return hash
-- end
  
-- local function getHandler(key)
--     local hash
--     local t = type (key)
--     if t == "string" then
--         hash = hash_str (key)
--     else
--         hash = hash_num (assert (tonumber (key)))
--     end
--     return math.ceil(hash % slaveCount + 1)
-- end