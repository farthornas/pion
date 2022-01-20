
p, buffer_count = nil, 0 --globals

timeout_wifi = tmr.create()
timeout_wifi:register(30000, tmr.ALARM_SINGLE, function()
            print("send to sleep, timeout on wifi connect")
            dofile("sleep.lua")
            end)

if file.exists("eus_params.lua") then
    p = dofile("eus_params.lua")
end

if file.open("buffer_count", "r+") then
    buffer_count = tonumber(file.read())
    print("buffer count " .. buffer_count)
end

function set_flag(n)
    if file.open("flags", "w+") then
        print("Set flag to: "..n)
        file.writeline(n)
        file.close()
    end
end

if file.exists("buttonPress2.lua") then
    dofile("buttonPress2.lua")
end

if file.exists("flag_check.lua") then
    print("Checking flags")
    dofile("flag_check.lua")
end
