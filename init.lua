local net, wifi, trig, now = net, wifi, gpio.trig, tmr.now
local EUS_FILE = "wifi_param.lua"
local TEST, DSLEEP = 4, 5
local t0, t1, t2 = 0, 0, 0
local data, shipment = {}, nil
local BUTTON = 3 -- Flash button on D3
local DURATION_FOR_START = 4000000 -- 4 seconds, dsleep duration
local TIMEOUT_DSLEEP = 5000 -- If not connected by this time - deep sleep
gpio.mode(BUTTON, gpio.INT, gpio.PULLUP)
local _, reset_reason = node.bootreason()
local data_sent = 0
local HOST, PORT, NAME, LOCATION, DURATION_SLEEP, BURST_TRANSFER = dofile("config.lua")

wifi.sta.connect()
print("Reset reason: "..reset_reason)
if reset_reason ~= DSLEEP then
    print("Unexpected reset reason: "..reset_reason)
    if file.exists("dsleepflag") then
        print("Removing deep sleep flag")
        file.remove("dsleepflag")
    end
end

local function pressed(level, t, eventcount)
    --Checking if button has been pressed
    --If button pressed longer than 4 seconds
    --the recording loop should start
    --For now button pressed longer than 4 seconds
    -- results in recording of sensorvalues
    if t1 == 0 then 
        t1 = t
    else
        t2 = t
        t0 = t2 - t1
        if t0 > DURATION_FOR_START then
            print("Button pressed for longer than "..DURATION_FOR_START)
            print("Starting data logging")      
            send_to_sleep(1000000)
        end
        print("Duration: "..t0)
        t1, t2, t0 = 0, 0, 0
    end
end

trig(BUTTON, "both", pressed) -- flash button pressed

wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
    print("\n\tSTA - GOT IP".."\n\tStation IP: "..T.IP.."\n\tSubnet mask: "..
    T.netmask.."\n\tGateway IP: "..T.gateway)
    wifi.eventmon.unregister(wifi.eventmon.STA_GOT_IP)
    if file.exists("dsleepflag") then
        print("Deepsleep flag detected, proceeding with logging sequence") 
        --data["sensors"] = dofile("read_sensors.lua")
        data["chip_info"] = node.info("hw")
        data["heap_space"] = node.heap()
        shipment = sjson.encode(data)
        print("Connecting to server...")
        srv = net.createConnection(net.TCP, 0)
        send_to_sleep(DURATION_SLEEP)
        srv:on("receive", function(sck, c) print(c) end)
        srv:on("connection", function(sck, c)
            print("Now connected")
            sck:send(shipment)
        end)
        srv:on("sent", function(sck, c) 
            print ("Message Sent")
            print("Disconnecting wifi..")
            wifi.sta.disconnect()
            data_sent = 1
        end)
        srv:connect(PORT, HOST)
    else
        print("No dsleepflag detected, awaiting further instructions...")
        print("Disconnecting from wifi to avaoid freeze")
        wifi.sta.disconnect()
    end
end)

function wifi_sta_setup()
    if wifi.sta.getip() ~= nil then
        -- if this is the case then should be ready to send data
        print("Wifi is connected to: "..wifi.sta.gethostname())
        print("IP: "..wifi.sta.getip())
    else
        -- if no ip first check if in station mode
        if wifi.getmode() == wifi.STATION then
            print("wifi in station mode") 
        else
        -- set to station mode
            wifi.setmode(wifi.STATION)
            print("wifi mode changing to station mode")
        end
        -- now check if EUS file is present on system
        if file.exists(EUS_FILE) then
            local p = dofile(EUS_FILE)
            local station_cfg={}
            station_cfg.ssid = p.wifi_ssid
            station_cfg.pwd = p.wifi_password
            station_cfg.save = true
            station_cfg.auto = false
            print("loading config parameters for wifi connection from EUS file")
            print("SSID: ".. p.wifi_ssid)
            print("Saving settings to flash..")
            wifi.sta.config(station_cfg)
        else
        --file does not appear to be present
            print("No EUS file present, run EUS setup to connect to desired wifi network and run wifi_sta_connect() again..")
        end
    end
end

function send_to_sleep(microsec)
    tmr.create():alarm(TIMEOUT_DSLEEP, tmr.ALARM_SINGLE, function()
        if data_sent ~= 1 and file.exists("dsleepflag") then
            print("Timeout on connecting to server")
            print("The data was not sent and will be lost...")
            print("Check if server is running...")
        end
        print("Going to Sleep for " .. microsec .. " us")
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
        wifi.sta.disconnect()
        --node.restart()
        node.dsleep(microsec)
    end)
end

function sensor_readings_buffer()
    local f = ""
    if file.open("counter", "r") then
        f = tonumber(file.readline())
        file.close()
    end
    if file.open("counter", "w+") then
        if f == "" then
            file.writeline("1")
        else
            f = f + 1
            file.writeline(f)
        end
        file.close()
    end
    if file.open("data_buffer", "a+") then
        data["sensors"] = dofile("read_sensors.lua")
        file.writeline(sjson.encode(data))
        file.close()
    end
end
        
