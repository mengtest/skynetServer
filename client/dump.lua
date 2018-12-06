-------------- mydump begin --------------
-- local syslog = require "syslog"
local tostring = tostring
local type = type
local string = string
local pairs = pairs

local tab_space = "    "
local function  get_tab_space(deepth)
    local str = ""
    for i=1,deepth do
        str = str .. tab_space
    end
    return str
end

local function mydump_tbl(tbl, deepth)
    if type(tbl) ~= "table" then return end
    deepth = deepth or 1
    local str = string.format("{\n")
    -- local str = string.format(""%s{ %s\n", get_tab_space(deepth - 1), tostring(tbl)) -- 打出table地址

    for k,v in pairs(tbl) do
        assert(type(k) ~= "table", "dont allow key = table")
        k = tostring(k)
        local line = string.format("%s\"%s\" = ", get_tab_space(deepth), k)
        if type(v) == "table" then
            line = string.format("%s%s,\n", line, mydump_tbl(v, deepth + 1))
        else
            line = string.format("%s%s,\n", line, tostring(v))
        end
        str = str .. line
    end

    str = string.format("%s%s}", str, get_tab_space(deepth - 1))
    return str
end


local function mydump(obj, descr)
    descr = descr or "mydump"
    local info = string.format("\"%s\" = ", descr)
    if type(obj) == "table" then
        info = info .. mydump_tbl(obj, 2)
    else
        info = info .. tostring(obj)
    end
    -- info = string.format("%s\n-- %s end--", info, descr)
    print(info)
end

return mydump