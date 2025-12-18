dofile("secrets.lua");

TCP_PORT = 10727;
PIN = 1;
wifi.setmode(wifi.STATION);
wifi.sta.config({
    ssid = WIFI_SSID,
    pwd = WIFI_PASSWORD,
});

local wifi_timer = tmr.create();
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
    last_timestamp = timestamp;
    local data = command .. timestamp;
    local expected_signature = to_hex(crypto.hmac("sha256", data, HMAC_KEY));
    return expected_signature == signature;
end

--- handle received packet
--- @param socket socket
--- @param data string
local function on_receival(socket, data)
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
        socket:send("Timestamp is not a numeral");
        return;
    end
    if validate(command, timestamp_num, signature) then
        if command == "open relay" then
            open_relay();
            socket:send("Opening relay");
        else
            socket:send("Invalid command");
            print("Invalid command");
        end
    else
        socket:send("Invalid signature or timestamp");
        print("Invalid signature or timestamp");
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

    server:listen(TCP_PORT, on_connection);
end

wifi_timer:alarm(1000, tmr.ALARM_AUTO, check_connection);

function STOP() -- stop running code for consistent uploads
    wifi_timer.stop(wifi_timer);
end
