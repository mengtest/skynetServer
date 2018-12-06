local skynet = require "skynet"
local syslog = require "syslog"
local dbpacker = require "db.packer"
local dump = require "common.dump"
local constant = require "constant"

local database
local CMD = {}

local role_info_table

local function find_role_by_id( id )
    for _,v in ipairs(role_info_table) do
        if v.ID == id then
            return v
        end
    end
end

local function find_role_by_name( name )
    for _,v in ipairs(role_info_table) do
        if v.NickName == name then
            return v
        end
    end
end

function CMD.change_name( id , name )
    local info = find_role_by_id(id)
    if not info then return end
    info.NickName = name
    return true
end


function CMD.name2id( name )
    local info = find_role_by_name( name )
    return info and info.ID
end

function CMD.id2name( id )
    local info = find_role_by_id( id )
    return info and info.NickName
end

function CMD.add_role( role_info )
    local role_id = role_info.role_id

    assert(find_role_by_id(role_id) == nil)

    local nickname = role_info.nickname
    local info = {
        ID = role_id,
        NickName = nickname,
    }
    table.insert( role_info_table, info )
end

function CMD.open ()
    syslog.debugf("--- name house open")
    database = skynet.uniqueservice ("database")
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)

    role_info_table = skynet.call(database, "lua", "account", "load_role_info")
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat friendserver")
end

local traceback = debug.traceback
skynet.start (function ()
    skynet.dispatch ("lua", function ( _, _ , command, ...)
        local f = CMD[command]
        if not f then
            syslog.warnf ("unhandled message(%s)", command)
            return skynet.ret ()
        end
        local function ret (ok, ...)
            if not ok then
                syslog.warnf ("handle message(%s) failed", command)
                skynet.ret ()
            else
                skynet.retpack (...)
            end  
        end
        ret (xpcall (f, traceback , ...))
    end)
end)

