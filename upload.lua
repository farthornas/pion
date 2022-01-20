--upload.lua

local wifi, tmr, http, rtctime = wifi, tmr, http, rtctime


-- need another timer here for in the event when files arent uploaded in time so device goes to sleep
local ip = wifi.sta.getip()
-- p is a global variable set in init.lua

local function upload()
    -- p is a global set in init.lua
    local buffer_count = 0
    if file.open("buffer_count", "r+") then
        buffer_count = tonumber(file.read())
    end

    local dev_info = "plant_readings,plant=" .. p.plant_name .. ",plant_location=" .. p.plant_location .. " "
    local sns_prd = "update_freq=" .. p.update_freq .. ",buffer_size=" .. p.m_buffer .. ","
    local meta_data = dev_info .. sns_prd
    local period = math.floor((tonumber(p.update_freq)*60)/tonumber(p.m_buffer) + 0.5)
    print("timestamp period: " .. period)
    local tnow, _, _  = rtctime.get()
    local tstamp = 0
    local url = 'https://europe-west1-1.gcp.cloud2.influxdata.com/api/v2/write?org=f56e703feef94052&bucket=demo&precision=s'
    local headers = 'Authorization: Token YS22siytEM-K4iNFWOkWx4ITfpvuvgK_rwLDFVM235W7ceJ1frWoaQM7Qjagt3j7cyqHPNQntEE4iWVmpQvodA==\r\nContent-Type: text/plain; charset=utf-8\r\nAccept: application/json'
    local body = ""
    if file.open("buffer") then
        for i = 1, buffer_count do
            tstamp = tnow - (buffer_count-i)*period
            local e = meta_data .. string.gsub(file.readline(), " ", "") .. " " .. tstamp
            body = body .. string.gsub(e,"\n", "") .. "\n"
            
            --print(body)
        end
        file.close()
        file.flush()
    end
    print(body)
    http.post(url,
      headers,
      body,
      function(code, data)
        if (code < 0) then
          print("HTTP request failed")
          set_flag(12)
        else
          print(code, data)
          set_flag(1)
          if file.exists("buffer_count") then
            print("Removing buffer_count")
            file.remove("buffer_count")
          end
          if file.exists("buffer") then
            print("Removing buffer")
            file.remove("buffer")
          end
        buffer_count = 0
        --wifi.sta.disconnect()
        end
        if file.exists("sleep.lua") then
            dofile("sleep.lua")
        end
      end)
end

local function sync()
    print("Attempting sync to sntp server")
    sntp.sync(nil,
      function(sec,usec,server,info)
        print('sntp sync successful', sec, usec, server)
        upload()
        end,
      function()
        print('sntp sync failed!')
        dofile("sleep.lua")
      end)
end

if ip ~= nil then
    print("Device has IP")
    print(wifi.sta.getip())
    sync()
else
    print("waiting for wifi connect")
    wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
      print("\n\tSTA - GOT IP".."\n\tStation IP: "..T.IP.."\n\tSubnet mask: "..
      T.netmask.."\n\tGateway IP: "..T.gateway)
      print("Signal Strength: " .. wifi.sta.getrssi())
      wifi.eventmon.unregister(wifi.eventmon.STA_GOT_IP)
      timeout_wifi:unregister()
      sync()
    end)
end
