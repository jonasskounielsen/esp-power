dofile("secrets.lua");

UDP_PORT = 10727;
PIN = 1;
wifi.setmode(wifi.STATION);
wifi.sta.config({
    ssid = WIFI_SSID,
    pwd = WIFI_PASSWORD,
});

local wifi_timer = tmr.create();
local was_connected = false;
local server = nil;
local last_timestamp = 0;

gpio.mode(PIN, gpio.OPENDRAIN);
gpio.write(PIN, gpio.HIGH);

--- open relay through gpio pin
local function open_relay()
    gpio.write(PIN, gpio.LOW)
    print("Opening relay");
    local timer = tmr.create();
    timer:alarm(500, tmr.ALARM_SINGLE, function()
        gpio.write(PIN, gpio.HIGH);
        print("Closing relay");
    end)
end

--- convert byte string to hex
--- @param str string
--- @return string
local function to_hex(str)
    ---@diagnostic disable-next-line: redundant-return-value
    return str:gsub(".", function (character)
        return string.format("%02x", string.byte(character));
    end);
end

--- validate message with hmac
--- @param command string
--- @param timestamp number
--- @param signature string
--- @return boolean
local function validate(command, timestamp, signature)
    if timestamp <= last_timestamp then
        return false;
    end
    local data = command .. timestamp;
    local expected_signature = to_hex(crypto.hmac("sha256", data, HMAC_KEY));
    if expected_signature == signature then
        last_timestamp = timestamp;
        return true;
    else
        return false;
    end
end

--- send packet safely
--- @param socket udpsocket
--- @param port integer
--- @param ip string
--- @param message string
local function socket_send(socket, port, ip, message)
    if socket then
        pcall(function()
            socket:send(port, ip, message);
        end);
    end
end

--- handle received packet
--- @param socket udpsocket
--- @param data string
--- @param port integer
--- @param ip string
local function on_receival(socket, data, port, ip)
    print("Received:");
    for line in (data .. "\n"):gmatch("(.-)\n") do
        print("    " .. line);
    end
    local lines = (data .. "\n"):gmatch("(.-)\n");
    local command = lines();
    local timestamp = lines();
    local signature = lines();

    local timestamp_num = tonumber(timestamp);
    if timestamp_num == nil then
        print("Timestamp is not a numeral");
        socket_send(socket, port, ip, "Timestamp is not a numeral");
    elseif validate(command, timestamp_num, signature) then
        if command == "open relay" then
            open_relay();
            socket_send(socket, port, ip, "Opening relay");
        else
            socket_send(socket, port, ip, "Invalid command");
            print("Invalid command");
        end
    else
        socket_send(socket, port, ip, "Invalid signature or timestamp");
        print("Invalid signature or timestamp");
    end
end

--- periodically check wifi connection
local function check_connection()
    local own_ip = wifi.sta.getip();
    local is_connected = own_ip ~= nil;

    if not is_connected and was_connected then
        wifi.sta.connect();
    end

    if not is_connected then
        print("Waiting for connection");
        if server then
            local local_server = server;
            server = nil;
            pcall(function()
                local_server:close();
            end);
        end
    end

    was_connected = is_connected;

    if server or not is_connected then
        return;
    end

    server = net.createUDPSocket();

    if not server then
        print("Failed to create server");
        return;
    end

    print("Connected");
    print("Hostname: " .. wifi.sta.gethostname());
    print("Ip: " .. own_ip);

    server:listen(UDP_PORT);

    ---@diagnostic disable-next-line: redundant-parameter
    server:on("receive", function (socket, data, port, ip)
        node.task.post(function ()
            on_receival(socket, tostring(data), port, ip);
        end);
    end);
end

wifi_timer:alarm(1000, tmr.ALARM_AUTO, check_connection);

tmr.create():alarm(60000, tmr.ALARM_SINGLE, function ()
    node.restart();
end);

--- stop running code for consistent uploads
function STOP()
    wifi_timer.stop(wifi_timer);
end
