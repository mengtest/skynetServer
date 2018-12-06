local skynet = require "skynet"
local quadtree = require "map.quadtree"
local syslog = require "syslog"
local dump = require "common.dump"

local math_ceil = math.ceil 
local math_abs = math.abs
local math_random = math.random

local aoi = {}

local object = {}
local qtree
local radius
local data

function aoi.init (bbox, r, d)
    syslog.debugf (string.format ("--- aoi, init, left:%d, bottom:%d, right:%d, top:%d, radius:%d", bbox.left, bbox.bottom, bbox.right, bbox.top, r))

    qtree = quadtree.new (bbox.left, bbox.bottom, bbox.right, bbox.top, nil)
    qtree:genChildren()
    radius = r
    data = d
    math.randomseed (os.time())

    -- dump(qtree, "root")
end

function aoi.check_pos(x, y)
    local x_ = math_ceil(x / 100)
    local y_ = math_ceil(y / 100)

    local sx = math_abs(qtree.right - qtree.left) / 100
    local sy = math_abs(qtree.top - qtree.bottom) / 100

    if x_ > 0 and x_ <= sx and y_ > 0 and y_ <= sy and data[y_][x_] == 0 then
        return true
    end

    return false
end

function aoi.random_pos(group)
    local sx = math_abs(qtree.right - qtree.left) / 100
    local sy = math_abs(qtree.top - qtree.bottom) / 100
    -- print("random_pos sx:", sx)
    -- print("random_pos sy:", sy)

    local x, y
    local offset = 1
    if group then
        offset = 3
    end
    while true do
        x = math_random(1+offset, sx-offset)
        y = math_random(1+offset, sy-offset)

        if data[y][x] == 0 then
            break
        end
    end

    local pos = {x = x * 100, y = y * 100}
    
    -- syslog.debugf (string.format("aoi.random_pos x:%d, y:%d, z:%d", pos.x, pos.y, pos.z))
    -- local pos = {x =100, y = 111, z = 0, o = 0}
    return pos
end

-- -- 查询周围的玩家和怪物
-- function aoi.query(id, race, pos)
--     if object[id] then return end

--     local result = {} 
--     qtree:query (id, pos.x - radius, pos.y - radius, pos.x + radius, pos.y + radius, result)

--     return result
-- end

function aoi.insert (id, race, pos)
    if object[id] then return end
    
    local tree = qtree:insert (id, race, pos.x, pos.y)
    if not tree then return end

    local result = {nil,nil,nil,nil,nil,nil,nil,nil,nil} 
    qtree:query (id, pos.x - radius, pos.y - radius, pos.x + radius, pos.y + radius, result)
    -- print("----------------------aoi.insert result:"..#result)
    -- dump(result, "----------------------aoi.insert result:")

    local list = {nil,nil,nil,nil,nil,nil,nil,nil,nil}
    for i = 1, #result do
        local cid = result[i].id
        local c = object[cid]
        if c then
            list[cid] = { ['id']=cid, ['race']=result[i].race ,['pos'] = result[i].pos  }
            c.list[id] = { ['id']=id, ['race']=race ,['pos'] = pos }
        end
    end

    object[id] = { id = id, race = race, pos = pos, qtree = tree, list = list }
    
    -- syslog.debugf (string.format("aoi.insert:%d, race:%d, x:%d, y:%d, z:%d", id, race, pos.x, pos.y, pos.z))

    return true, list, result
end

function aoi.remove (id)
    local c = object[id]
    if not c then return end

    if c.qtree then
        c.qtree:remove (id)
    else
        qtree:remove (id)
    end

    for _, v in pairs (c.list) do
        local t = object[v.id]
        if t then
            t.list[id] = nil
        end
    end
    object[id] = nil

    -- for i, v in pairs(object) do
    --     print("&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& remove object 1:"..i)

    --     for m, n in pairs(object[i].list) do
    --         print("&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& remove object 2:"..n.id)
    --     end
    -- end

    return true, c.list
end

function aoi.update (id, race, pos)
    local c = object[id]
    -- dump(object)
    
    -- for i, v in pairs(object) do
    --     print("&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& update object:"..i)

    --     for m, n in pairs(object[i].list) do
    --         print("&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&& update object:"..n.id)
    --     end
    -- end

    -- syslog.debugf (string.format("agent:%s, x:%d, y:%d, z:%d", id, pos.x, pos.y, pos.z))
    if not c then
        syslog.debugf ("--- not c, id:%d", id)
        return
    end

    if c.qtree then
        c.qtree:remove (id)
    else
        qtree:remove (id)
    end

    local olist = c.list
    -- dump(c.list, "&&&&&&&&&&&&&&&&&&&&&&&&&&&& c.list &&&&&&&&&&&&&&&&&&&&&")

    local tree = qtree:insert (id, race, pos.x, pos.y)
    if not tree then
        skynet.error ("--- not tree, id:%d", id,pos.x, pos.y)
        return
    end

    c.qtree = tree
    c.pos = pos

    local result = {nil,nil,nil,nil,nil,nil,nil,nil,nil}
    qtree:query (id, pos.x - radius, pos.y - radius, pos.x + radius, pos.y + radius, result)

    -- print("----------------------aoi.update result:"..#result)
    -- dump(result, "----------------------aoi.update result:")

    local nlist = {nil,nil,nil,nil,nil,nil,nil,nil,nil}
    for i = 1, #result do
        local cid = result[i].id
        nlist[cid] = { ['id'] = cid, ['race'] = result[i].race, ['pos'] = result[i].pos }

        local c2 = object[cid]
        if c2 then
            c2.list[id] = { ['id'] = id, ['race'] = race, ['pos'] = pos }
        end
    end

    local ulist = {nil,nil,nil,nil,nil}
    for id, a in pairs (nlist) do
        if olist[id] then
            ulist[id] = { ['id'] = id, ['race'] = a.race, ['pos'] = a.pos }
            olist[id] = nil
        end
    end

    for id, _ in pairs (ulist) do
        nlist[id] = nil
    end

    c.list = {nil,nil,nil,nil,nil}
    for id, v in pairs (nlist) do
        c.list[id] = v
    end
    for id, v in pairs (ulist) do
        c.list[id] = v
    end

    -- dump(c.list, "&&&&&&&&&&&&&&&&&&&&&&&&&&&& c.list &&&&&&&&&&&&&&&&&&&&&")
    -- dump(nlist, "&&&&&&&&&&&&&&&&&&&&&&&&&&&& nlist &&&&&&&&&&&&&&&&&&&&&")
    -- dump(ulist, "&&&&&&&&&&&&&&&&&&&&&&&&&&&& ulist &&&&&&&&&&&&&&&&&&&&&")
    -- dump(olist, "&&&&&&&&&&&&&&&&&&&&&&&&&&&& olist &&&&&&&&&&&&&&&&&&&&&")

    return true, nlist, ulist, olist
end

return aoi
