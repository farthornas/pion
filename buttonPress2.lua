local trig = gpio.trig
gpio.mode(3, gpio.INT, gpio.PULLUP)
local PSTART, PENDUSR = 4000000, 10000000
--local p_count,
local t0, t1, t2 = 0, 0, 0

local function flags(n)
    if file.open("flags", "w+") then
        file.writeline(n)
        file.close()
    end
end

local function pressed(level, t, eventcount)
    --p_count = p_count + 1

    if t1 == 0 then
        t1 = t
    else
        t2 = t
        t0 = t2 - t1
        if t0 > PENDUSR then -- button pressed longer than 4 seconds
            print("Button pressed for longer than "..PENDUSR)
            print("Start enduser setup")
            flags(2)
            node.restart()
        elseif t0 > PSTART then -- button pressed longer than 4 seconds
            print("Button pressed for longer than "..PSTART)
            print("Start datalogging")
            if file.exists("buffer") then
                file.remove("buffer")
            end
            if file.exists("buffer_count") then
                file.remove("buffer_count")
            end
            --send_to_sleep(1000000,1)
            flags(11)
            node.restart()
            --dofile("read_sensors2.lc")
            --print("Attempt connection to network")
            --wifi.sta.connect()

            --send_to_sleep(1000000,1)
            --dofile("read_sensors2.lc")
            --print("Attempt connection to network")
            --wifi.sta.connect()
        end
        print("Duration: "..t0)
        --print("Times Button Pressed "..p_count)
        --t1, t2, t0, p_count = 0, 0, 0, 0
        t1, t2, t0 = 0, 0, 0
    end
end
trig(3, "both", pressed) -- flash button pressed
