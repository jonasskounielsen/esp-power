local SSID = "";
local PASSWORD = "";

wifi.setmode(wifi.STATION);
wifi.sta.config({
    ssid = SSID,
    pwd = PASSWORD,
});

print(wifi.sta.getip());
print(wifi.sta.gethostname());
print(wifi.sta.getrssi());
