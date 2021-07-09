local net, wifi, trig, now = net, wifi, gpio.trig, tmr.now
local TEST, DSLEEP = 4, 5
local t0, t1, t2, t3, t4, t5, p_count = 0, 0, 0, 0, 0, 0, 0
local buffer, data, shipment, DATA_BUFFER = {}, {}, nil, "databuffer"
local BUTTON = 3 -- Flash button on D3
local DURATION_FOR_START = 4000000 -- 4 seconds, dsleep duration
local TIMEOUT_SERVER_CONNECT = 5000 -- If not connected by this time - deep sleep
gpio.mode(BUTTON, gpio.INT, gpio.PULLUP)
local _, reset_reason = node.bootreason()
local data_sent = 0 -- 0 = not attempted sent, 1 = data sent, 2 = data attempted sent
local buffer_count = 0
local server_port = 1234
local p = dofile('eus_params.lua')
local sense_interval = (p.report_period * 60000000)/p.m_buffer

if file.open("counter", "r") then
    buffer_count = tonumber(file.readline())
    file.flush()
    file.close()
end
wifi.sta.autoconnect(0)
wifi.sta.disconnect()
enduser_setup.stop()


function send_to_sleep(DS_us, timeout_ms)
    tmr.create():alarm(timeout_ms, tmr.ALARM_SINGLE, function()
        if data_sent == 2 and file.exists("dsleepflag") then
            print("Timeout on connecting to server")
            print("The data was not sent and will be lost...")
            print("Check if server is running...")
        end
        print("Going to Sleep for "..DS_us)
        if file.exists("dsleepflag") then
            print("dsleepflag already present")
        else
            print("dsleepflag being set")
            file.open("dsleepflag", "w")
            file.flush()
            file.close()
        end
        --print("dsleep not activated")
        --print("now rebooting to simulate dsleep")
        print("***********Wifi turning OFF!**********")
        wifi.sta.disconnect()
        print("**************************************")
        --node.restart()
        node.dsleep(DS_us)
    end)
end

function buffer_sensor_readings()
    print("Entering buffer for "..buffer_count)
    local buffer = {}
    if file.open("counter", "w+") then
        if buffer_count == 0 then
            file.writeline("1")
            buffer_count = 1
        else
            buffer_count = buffer_count + 1
            file.writeline(buffer_count)
        end
        file.flush()
        file.close()
    end
    --local tstamp = tmr.now()
    --temp["sens_time"] = tstamp
    --temp["sensors"] = dofile("read_sensors.lua")
    buffer["buffer"..buffer_count] = dofile("read_sensors.lua")
    if file.open(DATA_BUFFER, "a+") then
        file.writeline(sjson.encode(buffer))
    end
    file.flush()
    file.close()
end

--*************Checking Deep Sleep Start********************

print("Reset reason: "..reset_reason)
if reset_reason ~= DSLEEP then
    print("Unexpected reset reason: "..reset_reason)
    if file.exists("dsleepflag") then
        print("Removing deep sleep flag")
        print("***********Wifi turning OFF!**********")
        wifi.sta.disconnect()
        print("**************************************")
        file.remove("dsleepflag")
    else
        print("No Deepsleep flag...")
        print("***********Wifi turning OFF!**********")
        wifi.sta.disconnect()
        print("**************************************")
    end
end

if file.exists("dsleepflag") then
    buffer_sensor_readings()
    print("Deep sleep flag present")
    print("Checking Buffer Count. Transfer files at "..p.m_buffer)
    print("Buffer count currently at: "..buffer_count)
    if tonumber(buffer_count) >= tonumber(p.m_buffer) then
        print("Buffer filled - preparing to transfer")
        print("***********Wifi turning ON!**********")
        wifi.sta.connect()
        print("**************************************")
        print("Resetting buffer counter")
        file.remove("counter") -- reset buffer counter
    else
        print("Buffer not full, sending to sleep")
        send_to_sleep(sense_interval,4000)
    end
end

--*************Checking DeepSleep END********************

--**********************BUTTON START**********************

local function pressed(level, t, eventcount)
    --Checking if button has been pressed
    --If button pressed longer than 4 seconds
    --the recording loop should start

    --If button is pressed 3 times within a
    --2 second interval, the device will go into Wifi
    --STA mode to set reset wifi connection
    p_count = p_count + 1

    if t1 == 0 then
        t1 = t
    else
        t2 = t
        t0 = t2 - t1
        if t0 > DURATION_FOR_START then
            print("Button pressed for longer than "..DURATION_FOR_START)
            print("Starting data logging")
            send_to_sleep(1000000,1)
        end
        print("Duration: "..t0)
        print("Times Button Pressed"..p_count)
        t1, t2, t0 = 0, 0, 0
    end

    if t3 == 0 then
        t3 = t
    end
    if p_count == 6 then
        -- 6 button edges registered
        --The button has been pressed three times
        t4 = t
        t5 = t4 - t3
        if t5 < 2000000 then
            wifi.sta.clearconfig()
            --The button has been pressed 3 times within two seconds
            enduser_setup.start("Pion_"..node.chipid())
            wifi.sta.connect()
            print("Enduser setup has been initiated...")
        end
        t3, t4, t5 = 0, 0, 0
    end
end
trig(BUTTON, "both", pressed) -- flash button pressed

--**********************BUTTON END**********************

--**********************WIFI CONNECT START**********************

wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
    print("\n\tSTA - GOT IP".."\n\tStation IP: "..T.IP.."\n\tSubnet mask: "..
    T.netmask.."\n\tGateway IP: "..T.gateway)
    wifi.eventmon.unregister(wifi.eventmon.STA_GOT_IP)

    local buffer = {}
    local devinfo = {}
    --shipment = sjson.encode(data)
    if file.open(DATA_BUFFER) then
        for i = 1, buffer_count do
            buffer[i] = sjson.decode(file.readline())
        end
        file.close()
        file.remove(DATA_BUFFER)
        buffer_count = 0
    end

    devinfo["heap_space"] = node.heap()
    devinfo["chip_info"] = node.info("hw")
    devinfo["Plant Location"] = p.plant_location
    devinfo["Plant Name"] = p.plant_name
    devinfo["Report Period"] = p.report_period
    devinfo["Sensings pr report"] = p.m_buffer
    devinfo["sense_interval"] = sense_interval
    data["device_info"] = devinfo
    data["readings"] = buffer
    shipment = sjson.encode(data)
    print("Connecting to server...")
    data_sent = 2 -- data sending attempted
    srv = net.createConnection(net.TCP, 0)
    send_to_sleep(sense_interval,4000)
    srv:on("receive", function(sck, c) print(c) end)
    srv:on("connection", function(sck, c)
        print("Now connected")
        sck:send(shipment)
    end)
    srv:on("sent", function(sck, c)
        print ("Message Sent")
        print("Disconnecting wifi..")
        print("***********Wifi turning OFF!**********")
        wifi.sta.disconnect()
        print("**************************************")
        data_sent = 1
    end)
    srv:connect(server_port, p.server)
end)

--**********************WIFI CONNECT END**********************
