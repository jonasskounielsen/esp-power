dofile("wifi_credentials.lua");

wifi.setmode(wifi.STATION);
wifi.sta.config({
    ssid = SSID,
    pwd = PASSWORD,
});

TIMER = tmr.create();
TIMER.alarm(TIMER, 1000, tmr.ALARM_AUTO, function()
    print(wifi.sta.getip());
    print(wifi.sta.gethostname());
    print(wifi.sta.getrssi());
end);

function STOP() -- stop running code for consistent uploads
    TIMER.stop(TIMER);
end
