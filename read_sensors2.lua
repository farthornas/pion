local AUX_PWR_PIN, SEL0, SEL1, SEL2 = 1, 7, 6, 5 --7 lsb
local OUTPUT, gpio = gpio.OUTPUT, gpio
local pins = {AUX_PWR_PIN, SEL0, SEL1, SEL2}
local readings = " "

local function buffer(data)
    local buffer = {}
    local p = 1
    if file.open("buffer_count", "r+") then
        p = file.read()
        p = p + 1
        file.close()
    end
    if file.open("buffer", "a+") then
        file.writeline(data)
        file.close()
    end
    if file.open("buffer_count", "w+") then
        file.writeline(p)
        file.close()
    end
end

local function calib_sens()
    local measured_value1 = 0.1 
    local measured_value2 = 0.7
    local adc_max = 1023
    local correction = 0
    --Read calibtration value 1 at SENS1
    local adc_value1 = 0
    gpio.write(5,0)
    gpio.write(6,0)
    gpio.write(7,0)
    for i = 1, nreadings do
        local m = 0
        m = adc.read(0)
        print("Reading calibtration value 1:"..m)
        adc_value1 = adc_value1 + m
    end
    --Read calibtration value 2 at SENS2
    local adc_value2 = 0
    gpio.write(5,0)
    gpio.write(6,0)
    gpio.write(7,1)
    for i = 1, nreadings do
        local m = 0
        m = adc.read(0)
        print("Reading calibtration value 1:"..m)
        adc_value2 = adc_value2 + m
    end

    adc_error = adc_max - (adc_value2-adc_value1)/(measured_value2-measured_value1)
    correction = adc_error*(adc_value1/measured_value1)
    return correction
end
    


local function read_asensors()
    local nreadings, correction =  5, 0
    local sens = {"moist", "alight","temp", "brdtemp", "bat"}
    correction = calib_sens()
    sens.moist, sens.alight, sens.temp, sens.brdtemp, sens.bat = "000", "001", "100", "110", "111"
    print("Configure mux pins according to sensor to  be read")
    for k, v in ipairs(sens) do
        print("Reading "..v)
        local select = SEL2 -- msb to start
        local values = 0
        --local sum = 0
        for i = 1, #sens[v] do
            local c = sens[v]:sub(i,i)
            gpio.write(select, c)
            print("Set pin "..select.." to: "..c) 
            select = select + 1
        end
        print("Collecting " .. nreadings .. " adc values.")
        for i = 1, nreadings do
        local m, c = 0, 0
            m = adc.read(0)
            c = m + (m*correction) -- adc error correction
            --c = m
            print("Reading:"..c)
            values = values + c
        end
        readings = readings .. v .. "=" .. values/nreadings  
        if k ~= #sens then
            readings = readings .. ","
        end
    end
    buffer(readings)
end

read_asensors()
--read_dhtsensor() -- if used - buffer sensorreadings and set pinmode(2) (high Z) after
