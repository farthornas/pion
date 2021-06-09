local net, wifi, trig, now = net, wifi, gpio.trig, tmr.now
local TEST, DSLEEP = 4, 5
local t0, t1, t2, t3, t4, t5, p_count = 0, 0, 0, 0, 0, 0, 0
local data, shipment, DATA_BUFFER = {}, nil, "databuffer"
local BUTTON = 3 -- Flash button on D3
local DURATION_FOR_START = 4000000 -- 4 seconds, dsleep duration
local TIMEOUT_SERVER_CONNECT = 5000 -- If not connected by this time - deep sleep
gpio.mode(BUTTON, gpio.INT, gpio.PULLUP)
local _, reset_reason = node.bootreason()
local data_sent = 0 -- 0 = not attempted sent, 1 = data sent, 2 = data attempted sent
local buffer_count = 0
local server_port = 1234
local p = dofile('eus_params.lua')
local report_interval = (p.report_period * 10000000)/p.m_buffer
print(report_interval)
data["chip_info"] = node.info("hw")
data["Plant Location"] = p.plant_location
data["Plant Name"] = p.plant_name
data["Report Period"] = p.report_period
data["Sensings pr report"] = p.m_buffer
--local HOST, PORT, NAME, LOCATION, DURATION_SLEEP, BURST_TRANSFER = dofile("config.lua")
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
    local tstamp = tmr.now()
    data["sens_time"] = tstamp
    data["sensors"] = dofile("read_sensors.lua")
    if file.open(DATA_BUFFER, "a+") then
        file.writeline(sjson.encode(data))
    end
    file.flush()
    file.close()
end



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

--print("Checking for Deepsleep flag...")
if file.exists("dsleepflag") then
    buffer_sensor_readings()
    print("Deep sleep flag present")
    --buffer_sensor_readings()
    print("Checking Buffer Count. Transfer files at "..p.m_buffer)
    print("Buffer count currently at: "..buffer_count)
    if tonumber(buffer_count) >= tonumber(p.m_buffer) then
        print("Buffer filled - preparing to transfer")
        print("***********Wifi turning ON!**********")
        wifi.sta.connect()
        print("**************************************")
        print("Resetting buffer counter")
        file.remove("counter") -- reset buffer counter
        --file.remove(DATA_BUFFER)
    else
        print("Buffer not full, sending to sleep")
        send_to_sleep(report_interval,4000)      
    end
end


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

wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
    print("\n\tSTA - GOT IP".."\n\tStation IP: "..T.IP.."\n\tSubnet mask: "..
    T.netmask.."\n\tGateway IP: "..T.gateway)
    wifi.eventmon.unregister(wifi.eventmon.STA_GOT_IP)
    data["heap_space"] = node.heap()
    local buffer = nil
    --shipment = sjson.encode(data)
    if file.open(DATA_BUFFER) then
        buffer = sjson.decode(file.read())
        file.close()
    end
    data["readings"] = buffer
    shipment = sjson.encode(data)   
    print("Connecting to server...")
    data_sent = 2 -- data sending attempted
    srv = net.createConnection(net.TCP, 0)
    send_to_sleep(report_interval,4000)
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