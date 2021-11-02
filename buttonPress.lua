local trig = gpio.trig
local PSTART = 4000000
local p_count, t0, t1, t2 = 0, 0, 0, 0

local function pressed(level, t, eventcount)
    p_count = p_count + 1

    if t1 == 0 then
        t1 = t
    else
        t2 = t
        t0 = t2 - t1
        if t0 > PSTART then -- button pressed longer than 4 seconds
            print("Button pressed for longer than "..PSTART)
            print("Starting data logging")
            remove_buffer()
            --send_to_sleep(1000000,1)
            dofile("read_sensors2.lc")
            print("Attempt connection to network")
            wifi.sta.connect()
        end
        print("Duration: "..t0)
        print("Times Button Pressed "..p_count)
        --t1, t2, t0, p_count = 0, 0, 0, 0
        t1, t2, t0 = 0, 0, 0
    end

    if p_count == 6 then --button pressed 3 times
        if t0 < 2000000 then
            wifi.sta.clearconfig()
            file.remove('eus_params.lua')
            print(node.chipid())
            enduser_setup.start("Pion_"..node.chipid())
            print("Button pressed 3 times rapidly")
            print("Resetting wifi settings")
        end
        t1, t2, t0, p_count = 0, 0, 0, 0        
    end
    
end
trig(3, "both", pressed) -- flash button pressed

