DEVICE_PATH='/dev/serial/by-id/usb-1a86_USB2.0-Ser_-if00-port0'
if [ ! -e ./nodemcu-uploader/nodemcu-uploader.py ]; then
    git clone https://github.com/kmpm/nodemcu-uploader.git;
fi
if [ -c "$DEVICE_PATH" ]; then
    if [ -r "$DEVICE_PATH" ] && [ -w "$DEVICE_PATH" ]; then
        screen -S esp8266 -X stuff 'STOP()\n'
        screen -S esp8266 -X quit
        python3 ./nodemcu-uploader/nodemcu-uploader.py \
            --port "$DEVICE_PATH" \
            upload \
                ./init.lua:init.lua \
                ./secrets.lua:secrets.lua
        screen -dm -S esp8266 "$DEVICE_PATH" 115200
        screen -S esp8266 -X stuff 'node.restart()\n'
        screen -r esp8266
    else echo "$DEVICE_PATH not writable"
    fi
else echo "$DEVICE_PATH not found"
fi