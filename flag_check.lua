--check flags
local chipid = node.chipid()
local _, reset_reason = node.bootreason()
local flags, buffer_count = 0, 0
local AUX_PWR_PIN, SEL0, SEL1, SEL2 = 1, 7, 6, 5 --7 lsb
local pins = {AUX_PWR_PIN, SEL0, SEL1, SEL2}
local OUTPUT, gpio = gpio.OUTPUT, gpio
--flags = 1 Record mode active and last upload successful
--flags = 2 Wifi settings reset, prompt new settings restart, upload and go into record mode
--flags = 3 Device reset unexpectidly, could be many things user reset etc.
--flags = 11 Record mode just started, 

print("Reset reason: " .. reset_reason)

local function pinmode(n)
    for i=1, #pins do
        gpio.mode(pins[i], n)
    end
end

if reset_reason ~= 5 or p == nil then
    print("Deep sleep false")
    if reset_reason == 4 then
        print("Software reset")
    elseif p == nil then
        print("Software settings missing")
        set_flag(3)
    else
        print("Not booted from expected source")
        set_flag(3)
    end
end

if file.open("flags", "r+") then
    flags = tonumber(file.read())
end

if flags == 1 or flags == 11 or flags == 12 then -- record mode active
    pinmode(OUTPUT)
    gpio.write(AUX_PWR_PIN, 1)
    tmr.create():alarm(1000, tmr.ALARM_SINGLE, function()
        print("read analog sensors")
        if file.exists("read_sensors2.lua") then      
            dofile("read_sensors2.lua")
            pinmode(2)
                --gpio.write(AUX_PWR_PIN, 1)
        end
        
        if file.open("buffer_count", "r+") then
            buffer_count = tonumber(file.read())
        end
        -- p is a global set in init.lua
        print("buffer states and settings")
        print(buffer_count)
        print(tonumber(p.m_buffer))
        if (buffer_count >= tonumber(p.m_buffer)) or (flags == 11) then
            if file.exists("upload.lua") then
                dofile("upload.lua")
            end
            print("attemp connect to wifi")
            wifi.sta.connect()
            timeout_wifi:start()
        else
            if file.exists("sleep.lua") then
                dofile("sleep.lua")
            end
        end
        end)
elseif flags == 2 then -- reset of wifi settings
    print("wifi settings reset")
    wifi.sta.clearconfig()
    enduser_setup.start("Pion_"..chipid,  
    function()
        print("Connected to WiFi with IP:" .. wifi.sta.getip())
        --could add signal strength here
        set_flag(11)
        local restart = tmr.create()
        restart:register(4000, tmr.ALARM_SINGLE, function (t)
            t:unregister()  
            node.restart()
        end)
        restart:start()
    end
    )
else -- Device reset Unexpected
    -- this could be anything??
    print("Unexpected reset or network issues, waiting for input")
end
