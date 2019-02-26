local cmd = {}
local connection_handler
local table_insert = table.insert

local function make_key (account)
    return connection_handler (account)
end

function cmd.init (ch)
	connection_handler = ch
end
----------------------------------------------------

function cmd.saveResultInfo(account, info)
    local ret
    for _,args in pairs(info) do
        local mongodb = make_key(account)
        local moudleBase = args.moudleBase
        local grade = moudleBase.grade
        local term = moudleBase.term
        local unit = moudleBase.unit
        local moudleId = moudleBase.moudleId
    -- table_insert(info,{moudleBase = moudleBase,order = order,score = {args.score}})
        ret = mongodb.ResultInfo:findOne({ID = account,['Record.moudleBase.grade'] = grade, ['Record.moudleBase.term'] = term,['Record.moudleBase.unit'] = unit,['Record.moudleBase.moudleId'] = moudleId})
        if not ret then
            ret = mongodb.ResultInfo:safe_update({ID = account},{["$push"] = {Record = args}},true)
        else
            ret = mongodb.ResultInfo:safe_update({ID = account,['Record.moudleBase.grade'] = grade, ['Record.moudleBase.term'] = term,['Record.moudleBase.unit'] = unit,['Record.moudleBase.moudleId'] = moudleId},{["$set"] = {['Record.$'] = args}},true)
        end
    end
    return ret
    -- return mongodb.ResultInfo:safe_update({ID = account, ['Record.Grade'] = grade, ['Record.Term'] = term,['Record.Unit'] = unit,['Record.MoudleId'] = moudleId,['Record.Order'] = order},{["$push"] = {Record = record}},true)
end

function cmd.getResultInfo(account, args) 
    local mongodb = make_key(account)
    local ret = mongodb.ResultInfo:find({ID = account},{['_id']=0,['ID']=0})
    local info = {}
    if ret and ret:hasNext() then
        local ac = ret:next()
        info = ac.Record
    end
    return info
end

--,Grade = grade,Term = term,Unit = unit,MoudleId = moudleId,Order = order
return cmd
