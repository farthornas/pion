AUX_PWR_PIN, SEL0, SEL1, SEL2 = 1, 7, 6, 5
local pins = {AUX_PWR_PIN, SEL0, SEL1, SEL2}
local sens = {"moist", "alight", "temp", "brdtemp", "bat"}
sens.moist, sens.alight, sens.temp, sens.brdtemp, sens.bat = "000", "001", "010", "110", "111"
local OUTPUT = gpio.OUTPUT
local readings  = {}

local function buffer(data)
    local buffer = {}
    local p = 1
    if file.open("buffer_count", "r+") then
        p = file.read()
        p = p + 1
        file.close()
    end
    if file.open("buffer", "a+") then
        buffer["buffer"..p] = data
        file.writeline(sjson.encode(buffer))
        file.close()
    end
    if file.open("buffer_count", "w+") then
        file.writeline(p)
        file.close()
    end
end

local function read_sensors(sens)
    print("Set up aux power and mux pins to output")
    for i=1, #pins do
        gpio.mode(pins[i], OUTPUT)
    end
    gpio.write(AUX_PWR_PIN, 1)
    print("Configure mux pins according to sensor to  be read")
    for k, v in ipairs(sens) do
        print("Reading "..v)
        local select = SEL2 -- msb to start
        local values = {}
        --local sum = 0
        for i = 1, #sens[v] do
            local c = sens[v]:sub(i,i)
            gpio.write(select, c)
            print("Set pin "..select.." to: "..c) 
            select = select + 1
        end
        print("Collecting 10 adc values.")
        for i = 1, 10 do
            m = adc.read(0)
            print("Reading:"..m)
            values[i] = m
        end
        readings[v]=values        
    end
    buffer(readings)
    print("Turn off aux power and mux pins to HighZ")
    for i=1, #pins do
        gpio.mode(pins[i], 2)
    end
end

read_sensors(sens)
