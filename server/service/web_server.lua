local skynet = require "skynet"
-- local socket = require "socket"
local socket = require "skynet.socket"
local syslog = require "syslog"
local httpd = require "http.httpd"
local dbpacker = require "db.packer"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local table = table
local string = string

local mode = ...

if mode == "agent" then

local database
local nameserver
local friendserver

skynet.init(function()
    database = skynet.uniqueservice ("database")
    friendserver = skynet.uniqueservice ("friend_server")
    nameserver = skynet.uniqueservice ("name_house")
end)

local function response(id, ...)
    local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
    if not ok then
        -- if err == sockethelper.socket_error , that means socket closed.
        skynet.error(string.format("fd = %d, %s", id, err))
    end
end

skynet.start(function()
    skynet.dispatch("lua", function (_,_,id)
        socket.start(id)
        -- limit request body size to 8192 (you can pass nil to unlimit)
        local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
        if code then
            if code ~= 200 then
                response(id, code)
            else
                local tmp = {}
                -- if header.host then
                --     table.insert(tmp, string.format("host: %s", header.host))
                -- end
                local path, query = urllib.parse(url)
                -- table.insert(tmp, string.format("path: %s", path))
                if query then
                    local q = urllib.parse_query(query)
                    -- for k, v in pairs(q) do
                    --     if k == 'id' then
                    --         local account = tonumber(v)
                    --         if account then
                    --             local _ , agent = skynet.call( friendserver, 'lua', 'check_online', account )
                    --             if agent then
                    --                 skynet.call( agent, 'lua', 'update_self_info' )
                    --                 table.insert(tmp, string.format("%s: %d UPDATE OK", type(account),account))
                    --             else
                    --                 local name = skynet.call( nameserver, "lua", "id2name", account )
                    --                 if not name then
                    --                     table.insert(tmp, string.format("%s id error not exist",v))
                    --                 else
                    --                     table.insert(tmp, string.format("%s: %d UPDATE OK", type(account),account))
                    --                 end
                    --             end
                    --         else
                    --             table.insert(tmp, string.format("%s id format error ",v))
                    --         end
                    --     end
                    -- end
                end
                -- table.insert(tmp, "-----header----")
                -- for k,v in pairs(header) do
                --     table.insert(tmp, string.format("%s = %s",k,v))
                -- end
                -- table.insert(tmp, "-----body----\n" .. body.."\n")

                -- -- test load data from database
                -- local allList = skynet.call(database, "lua", "account", "loadlist")
                -- local json = dbpacker.pack(allList)
                -- table.insert(tmp, "-----ret data----\n" .. json.."\n")
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
    end)
end)

else

local CMD = {}
function CMD.open ()
    syslog.debugf("--- web server open")
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat webserver")
end

local traceback = debug.traceback
skynet.start(function()
    local agent = {}
    for i= 1, 20 do
        agent[i] = skynet.newservice(SERVICE_NAME, "agent")
    end
    local balance = 1
    local id = socket.listen("0.0.0.0", 8001)
    skynet.error("Listen web port 8001")
    socket.start(id , function(id, addr)
        skynet.error(string.format("%s connected, pass it to agent :%08x", addr, agent[balance]))
        skynet.send(agent[balance], "lua", id)
        balance = balance + 1
        if balance > #agent then
            balance = 1
        end
    end)

    skynet.dispatch ("lua", function (_, _, command, ...)
        local f = CMD[command]
        if not f then
            syslog.warnf ("unhandled message(%s)", command)
            return skynet.ret ()
        end

        local ok, ret = xpcall (f, traceback, ...)
        if not ok then
            syslog.warnf ("handle message(%s) failed : %s", command, ret)
            -- kick_self ()
            return skynet.ret ()
        end
        skynet.retpack (ret)
    end)
end)

end
