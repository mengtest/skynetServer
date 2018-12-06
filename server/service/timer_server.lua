local skynet = require "skynet"
local syslog = require "syslog"
local dbpacker = require "db.packer"
local dump = require "common.dump"
local constant = require "constant"

local CMD = {}

local chatserver
local lasthour
local last_five_sec = 0

local function on_new_day_come()
    -- skynet.send (rankserver, "lua", "clean_kill_rank")

    local online_tbl = skynet.call (chatserver, "lua", "getOnline")
    for _,v in pairs(online_tbl) do
        skynet.send (v.agent, "lua", "on_new_day_come") 
    end
end

local function check_new_hour_come()
    local nowhour = os.date ('*t').hour
    if nowhour ~= lasthour then
        lasthour = nowhour
        if lasthour == 0 then 
            on_new_day_come()
        end
    end
end

local function five_sec_tick(source)
    if os.time() > last_five_sec then
        last_five_sec = os.time() + 5
        skynet.send (source, "lua", "five_sec_tick") 
    end
end

local function timer(source)
    local lasttime
    local nowtime
    while true do
        skynet.sleep(20)
        nowtime = os.time()
        if nowtime ~= lasttime then
            lasttime = nowtime
            check_new_hour_come()
            five_sec_tick(source)
        end
    end
end


function CMD.open ( source , conf)
    syslog.debugf("--- timer server open")
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)

    chatserver = skynet.uniqueservice ("chat_server")
    skynet.fork(timer,source)
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat timerserver")
end

local traceback = debug.traceback
skynet.start (function ()
    skynet.dispatch ("lua", function (_, source, command, ...)
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
        ret (xpcall (f, traceback , source, ...))
    end)
end)
