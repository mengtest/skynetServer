local skynet = require "skynet"
local syslog = require "syslog"
local dbpacker = require "db.packer"
local dump = require "common.dump"
local constant = require "constant"

local database
local CMD = {}
local last_send_time
local mail_accumulate = 0

local function save_mail( target_id, mail_info )
    skynet.call(database, "lua", "mail", "save_mail",target_id, mail_info)
end

 function CMD.generate_mail_id()
    local nowtime = math.floor(skynet.time())
    if last_send_time and last_send_time == nowtime then
        mail_accumulate = mail_accumulate + 1
    else 
        mail_accumulate = 0
    end
    last_send_time = nowtime
    return nowtime .. mail_accumulate
end

function CMD.open (source, conf)
    syslog.debugf("--- mail server open")
    database = skynet.uniqueservice ("database")
    local moniter = skynet.uniqueservice ("moniter")
    skynet.call(moniter, "lua", "register", SERVICE_NAME)
end


function CMD.send_mail_target( _ , target_id, mail_info )
    local friendserver = skynet.uniqueservice ("friend_server")
    local _ , target_agent = skynet.call(friendserver, "lua", "check_online", target_id) 
    mail_info.status = constant.Undisposed
    if target_agent then
        skynet.call( target_agent ,"lua", "receive_mail", mail_info)
    else
        save_mail(target_id, mail_info)
    end
end

function CMD.cmd_heart_beat ()
    -- syslog.debugf("--- cmd_heart_beat mailserver")
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
