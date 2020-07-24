--upvals
local gpio, node, adc, tmr, sjson = gpio, node, adc, tmr, sjson
local OUTPUT, INPUT, FLOAT, HIGH, LOW = gpio.OUTPUT, gpio.INPUT, gpio.FLOAT,gpio.HIGH, gpio.LOW
local AUX_PWR_PIN, MOIST, SEL0, SEL1, SEL2, BUT = 1, 2, 7, 6, 5, 3 -- D1, D2, D7, D6, D5, D3 pins on nodeMCU (D3 flash button)
local ON, OFF, HIGH_Z = 1, 0, 2 -- pin states
local MSTR, LGT, BRDTMP, BAT = "soil_moisture", "ambient_light", "board_temperature", "battery_voltage" -- Sens value placeholders 
local SENSDELAY = 100 -- sensor delay to allow aux turn on and change of MUX configuration 


--local variables

--GPIO setup functions START
local function set_gpio_conf(pins, in_out_high_z)
--take a list of gpio pins to set as in or outputs
    print("Configuring pins direction...")
    for i = 1, #pins   do
        if in_out_high_z == HIGH_Z then
            print("Setting high_z on pin:"..pins[i])
            gpio.mode(pins[i], INPUT, FLOAT)
        else
            print("Setting pin: "..pins[i].." to : "..in_out_high_z..", 0 = input, 1 = output")
            gpio.mode(pins[i], in_out_high_z)
        end
    end
end

--SETTUP BUTTON

--GPIO setup functions END

local function read_adc(n)
    --Function returning a table of values and their average 
    local values = {}
    local sum = 0
    print("Reading "..n.." adc values.")
    for i = 1, 10 do
        m = adc.read(0)
        values[i] = m
        sum = sum + m   
    end
    return {val=values, avg = sum/#values}
end

-- aux power START
local function aux_power(on_off)
    if on_off == 1 then
        print("TURNING ON AUX power")
        set_gpio_conf({AUX_PWR_PIN}, OUTPUT)
        gpio.write(AUX_PWR_PIN, ON)
    else
        print("TURNING OFF AUX power")
        set_gpio_conf({AUX_PWR_PIN}, HIGH_Z)
    end
end
-- aux power END

-- MUX select START
local function mux_select(s2,s1,s0)
    --MUX requires auxilary power to operate
    --s2 s1 s0  = 001 would select chnl 1 etc... 
    set_gpio_conf({SEL2,SEL1,SEL0}, OUTPUT)
    print("Selecting channel: "..s2.." "..s1.." "..s0)
    gpio.write(SEL2, s2)
    gpio.write(SEL1, s1)
    gpio.write(SEL0, s0)
end
-- MUX select END

-- moisture sensor read START
local function moisture()
    --Require aux_power to be on to opertate
    print("Setting up for moisture reading...")
    local moisture_reading = {}
    local i = (node.random(2) % 2) 
    set_gpio_conf({MOIST}, OUTPUT) -- configure pins for logic circuit operation
    print("Reading moisture sensor with polaity set: "..i..", 0 = top, 1 = bot")
    gpio.write(MOIST, i) -- set pin according to rand value (0 or 1)
    local k = 1 % i -- complementary of what i is 
    mux_select(0,0,k) -- select corresponding mux line.
    moisture_reading = read_adc(10) -- read moisture sensor
    set_gpio_conf({SEL0, SEL1, SEL2, MOIST}, HIGH_Z) -- clean pin states
    print("Moisture reading finished")
    return moisture_reading
end
-- moisture sensor read END

-- Ambient light read START
local function alight()
    --Require aux_power to be on to opertate
    print("Setting up for ambient light reading...")
    local algt = {}
    mux_select(0,1,0) -- sensor 7 = board temp sensor
    print("Reading ambient lighting ...")
    algt = read_adc(10)
    set_gpio_conf({SEL0, SEL1, SEL2}, HIGH_Z) -- clean pin states
    print("Ambient light reading finished")
    return algt
end
-- Ambient light read END

-- Board temperature sensor read START
local function boardtemp()
    --Require aux_power to be on to opertate
    print("Setting up for board temperature reading...")
    local brd_temp = {}
    mux_select(1,1,0) -- sensor 7 = board temp sensor
    print("Reading board temperature ...")
    brd_temp = read_adc(10)
    set_gpio_conf({SEL0, SEL1, SEL2}, HIGH_Z) -- clean pin states
    print("Board temperature reading finished")
    return brd_temp
end
-- Board temperature sensor read END

-- Battery voltage read START
local function vbattery()
    --Require aux_power to be on to opertate
    print("Setting up for battery voltage reading...")
    local vbat = {}
    mux_select(1,1,1) -- sensor 8 = batery voltage sensor
    print("Reading battery voltage ...")
    vbat = read_adc(10)
    set_gpio_conf({SEL0, SEL1, SEL2}, HIGH_Z) -- clean pin states
    print("Battery voltage reading finished")
    return vbat
end
-- Battery voltage read END

--  Read sensors 
local function sens_read()
    --Returns the readings of the sensors in a json encoded format
    local readings = {}
    aux_power(ON)
    print("Aux power turned on")
    tmr.delay(SENSDELAY)
    readings[MSTR] = moisture()
    tmr.delay(SENSDELAY)
    readings[LGT] = alight()
    tmr.delay(SENSDELAY)
    readings[BRDTMP] = boardtemp()
    tmr.delay(SENSDELAY)
    readings[BAT] = vbattery()    
    aux_power(OFF)
    return readings
end

return sens_read()
