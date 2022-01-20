local timeout_ms = 2000
-- p is a global variable set in init.lua
tmr.create():alarm(timeout_ms, tmr.ALARM_SINGLE, function()
    print("send to sleep")
    local buffer_count = 0
    if file.open("buffer_count", "r+") then
        buffer_count = tonumber(file.read())
    end
    local m_buffer = tonumber(p.m_buffer)
    local sens_interval = (p.update_freq * 60000000)/m_buffer 
    print("Going to sleep for: " .. sens_interval .. " us")
    --print(sens_interval)
    --print("us")
    local b = buffer_count + 1
    if m_buffer > b then 
        node.dsleep(sens_interval, 4)-- 4 = no rf on wakeup
        print("No rf on wakeup")
    else
        node.dsleep(sens_interval)
    end
end)
