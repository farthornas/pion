local net, wifi, trig, now, chipid = net, wifi, gpio.trig, tmr.now, node.chipid()
local TEST, DSLEEP = 4, 5
local t0, t1, t2, p_count = 0, 0, 0, 0
--local BUTTON = 3 -- Flash button on D3
local PSTART = 4000000 -- 4 seconds, dsleep duration
local TIMEOUT_SERVER_CONNECT = 5000 -- If not connected by this time - deep sleep
gpio.mode(3, gpio.INT, gpio.PULLUP)
local _, reset_reason = node.bootreason()
local data_sent = 0 -- 0 = not attempted sent, 1 = data sent, 2 = data attempted sent
local buffer_count = 0
local server_port = 1234
local devinfo = {}
local p = nil
enduser_setup.stop()
if file.exists('eus_params.lua') then
    --We should only read some of these on send 
    p = dofile('eus_params.lua')
end
--devinfo["chip_info"] = node.info("hw")

function remove_buffer()
    if file.exists("buffer_count") then
        print("Removing buffer_count")
        file.remove("buffer_count")
    end
    if file.exists("buffer") then
        print("Removing buffer")
        file.remove("buffer")
    end
        buffer_count = 0
end

if reset_reason ~= DSLEEP then
    print("Unexpected reset reason: "..reset_reason)
    print("***********Wifi turning OFF!**********")
    wifi.sta.disconnect()
    print("**************************************")
    remove_buffer()
    --remove_buffer()
    if file.exists("dsleepflag") then
        print("Removing deep sleep flag")
        file.remove("dsleepflag")
    else
        print("No Deepsleep flag...")
    end
end

dofile("read_sensors2.lc")

if file.open("buffer_count", "r+") then
    buffer_count = file.read()
    file.close()
end
-- ************* FUNCTIONS ****************

function remove_buffer()
    if file.exists("buffer_count") then
        print("Removing buffer_count")
        file.remove("buffer_count")
    end
    if file.exists("buffer") then
        print("Removing buffer")
        file.remove("buffer")
    end
        buffer_count = 0
end

local function send_to_sleep(DS_us, timeout_ms)
    tmr.create():alarm(timeout_ms, tmr.ALARM_SINGLE, function()
        if data_sent == 2 and file.exists("dsleepflag") then
            print("Timeout on connecting to server")
            print("The data was not sent and will be lost...")
            remove_buffer()
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
        node.dsleep(DS_us)
    end)
end

-- ************* FUNCTIONS  END****************

--*************Checking Deep Sleep Start********************
if file.exists("dsleepflag") then
    print("Deep sleep flag present")
    print("Checking Buffer Count. Transfer files at "..p.m_buffer)
    print("Buffer count currently at: "..buffer_count)
    --buffer_sensor_readings()
    if tonumber(buffer_count) >= tonumber(p.m_buffer) then
        print("Buffer filled - preparing to transfer")
        print("***********Wifi turning ON!**********")
        wifi.sta.connect()
        print("**************************************")
    else
        print("Buffer not full, sending to sleep")
        local sens_interval = (p.report_period * 60000000)/p.m_buffer
        send_to_sleep(sens_interval,4000)
    end
end
--*************Checking DeepSleep END********************


dofile("buttonPress.lc")

--**********************WIFI CONNECT START**********************

wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
    print("\n\tSTA - GOT IP".."\n\tStation IP: "..T.IP.."\n\tSubnet mask: "..
    T.netmask.."\n\tGateway IP: "..T.gateway)
    wifi.eventmon.unregister(wifi.eventmon.STA_GOT_IP)
    local ssid, _, _, _ = wifi.sta.getconfig()
    local data = {}
    local buffer = {}
    local shipment = {}
    
    --shipment = sjson.encode(data)
    if file.open("buffer") then
        for i = 1, buffer_count do
            print("Buffer Count "..buffer_count)
            buffer[i] = sjson.decode(file.readline())
        end
        file.close()
        file.flush()
    end
    

    print(p.report_period, p.m_buffer)
    devinfo["sense_interval"] = (p.report_period * 60000000)/p.m_buffer
    devinfo["Plant Location"] = p.plant_location
    devinfo["Plant Name"] = p.plant_name
    devinfo["Report Period"] = p.report_period
    devinfo["Sensings pr report"] = p.m_buffer
    devinfo["chip_info"] = node.info("hw")
    devinfo["heap_space"] = node.heap()
    devinfo["sta_rssi"] = wifi.sta.getrssi()
    devinfo["ssid"] = ssid
    data["device_info"] = devinfo
    data["readings"] = buffer
    shipment = sjson.encode(data)
    print(shipment)
    print("Connecting to server...")
    data_sent = 2 -- data sending attempted
    srv = net.createConnection(net.TCP, 0)
    send_to_sleep(devinfo["sense_interval"],4000)
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
        remove_buffer()
    end)
    srv:connect(server_port, p.server)
end)

--**********************WIFI CONNECT END**********************
