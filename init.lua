dofile("secrets.lua");

PIN = 1;
wifi.setmode(wifi.STATION);
wifi.sta.config({
    ssid = WIFI_SSID,
    pwd = WIFI_PASSWORD,
});

local wifi_timer = tmr.create();

gpio.mode(PIN, gpio.OUTPUT);
gpio.write(PIN, gpio.LOW);

--- open relay through gpio pin
local function open_relay()
    gpio.write(PIN, gpio.HIGH)
    local timer = tmr.create();
    timer:alarm(3000, tmr.ALARM_SINGLE, function()
        gpio.write(PIN, gpio.LOW);
    end)
end
--- handle received packet
--- @param socket socket
--- @param data string
local function on_receival(socket, data)
    print("Received:");
    for line in (data .. "\n"):gmatch("(.-)\n") do
        print("    " .. line);
    end
    local stripped_data = data:match("^%s*(.-)%s*$");
    if stripped_data == PASSWORD then
        open_relay();
        print("Opening relay");
        socket:send("Opening relay");
    end
    socket:close();
end

--- handle received connection request
--- @param connection socket
local function on_connection(connection)
    connection:on("receive", on_receival);
end

local function check_connection()
    local ip = wifi.sta.getip();

    if not ip then
        print("Waiting for connection");
        return;
    end

    print("Connected");
    print("Hostname: " .. wifi.sta.gethostname());
    print("Ip: " .. ip);
    wifi_timer:stop();

    local server = net.createServer(net.TCP);

    if not server then
        print("Failed to create server");
        return;
    end

    server:listen(80, on_connection);
end

wifi_timer:alarm(1000, tmr.ALARM_AUTO, check_connection);

function STOP() -- stop running code for consistent uploads
    wifi_timer.stop(wifi_timer);
end
