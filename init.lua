dofile("wifi_credentials.lua");

wifi.setmode(wifi.STATION);
wifi.sta.config({
    ssid = SSID,
    pwd = PASSWORD,
});

local wifi_timer = tmr.create();

--- handle received packet
--- @param socket socket
--- @param data string
local function on_receival(socket, data)
    print("");
    print("Received:");
    for line in (data .. "\n"):gmatch("(.-)\n") do
        print("    " .. line);
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
