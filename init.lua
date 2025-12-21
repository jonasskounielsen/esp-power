dofile("secrets.lua");

TCP_PORT = 10727;
PIN = 1;
wifi.setmode(wifi.STATION);
wifi.sta.config({
    ssid = WIFI_SSID,
    pwd = WIFI_PASSWORD,
});

wifi_timer = tmr.create();
was_connected = false;
server = nil;
last_timestamp = 0;

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
--- @param socket socket
--- @param callback function
local function socket_send(socket, message, callback)
    if socket then
        pcall(function()
            socket:send(message, callback);
        end);
    end
end

--- close socket safely
--- @param socket socket
local function close_socket(socket)
    if socket then
        pcall(function()
            socket:close();
        end);
    end
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
        socket_send(socket, "Timestamp is not a numeral", function ()
            close_socket(socket);
        end);
    elseif validate(command, timestamp_num, signature) then
        if command == "open relay" then
            open_relay();
            socket_send(socket, "Opening relay", function ()
                close_socket(socket);
            end);
        else
            socket_send(socket, "Invalid command", function ()
                close_socket(socket);
            end);
            print("Invalid command");
        end
    else
        socket_send(socket, "Invalid signature or timestamp", function ()
            close_socket(socket);
        end);
        print("Invalid signature or timestamp");
    end
end

--- handle received connection request
--- @param connection socket
local function on_connection(connection)
    connection:on("receive", function (socket, data)
        node.task.post(function ()
            on_receival(socket, tostring(data));
        end);
    end);
    connection:on("disconnection", function (socket, error)
        print(socket:getpeer());
            close_socket(socket);
        print("Disconnected with code: " .. error);
    end);
end

local function check_connection()
    local ip = wifi.sta.getip();
    local is_connected = ip ~= nil;

    if not is_connected and was_connected then
        wifi.sta.connect();
    end

    if not is_connected then
        print("Waiting for connection");
        if server then
            local s = server;
            server = nil;
            pcall(function()
                s:close();
            end);
        end
    end

    was_connected = is_connected;

    if server or not is_connected then
        return;
    end

    server = net.createServer(net.TCP);

    if not server then
        print("Failed to create server");
        return;
    end

    print("Connected");
    print("Hostname: " .. wifi.sta.gethostname());
    print("Ip: " .. ip);

    server:listen(TCP_PORT, on_connection);
end

wifi_timer:alarm(1000, tmr.ALARM_AUTO, check_connection);

function STOP() -- stop running code for consistent uploads
    wifi_timer.stop(wifi_timer);
end
