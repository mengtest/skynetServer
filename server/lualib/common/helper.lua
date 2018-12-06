local M = {}

--取字符串的长度，包含中文
function M.get_string_len(input)
    local len  = string.len(input)
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string.byte(input, -left)
        local i = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt
end

--判断time 和当前时间 是否是同一天   不是 返回 true
function M.check_another_day( time )
    if not time then
        return true
    end
    local t1 = os.date('*t')
    local t2 = os.date('*t',time)
    if t1.year ~= t2.year then
        return true
    end
    if t1.yday ~= t2.yday then
        return true
    end
end

-- 返回当天凌晨的时间戳 + addtime     addtime 必须是秒为单位的  可以为负数
function M.get_day_time_addtime(addtime)
    local time = os.date('*t')
    local daytime = os.time({['year']=time.year,['month']=time.month,['day']=time.day,['hour']=0})
    return daytime + addtime
end 

return M
