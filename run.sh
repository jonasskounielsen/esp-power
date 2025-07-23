screen -S esp8266 -X quit
python3 ./nodemcu-uploader/nodemcu-uploader.py \
    --port /dev/serial/by-id/usb-1a86_USB2.0-Ser_-if00-port0 \
    upload init.lua
screen -dm -S esp8266 /dev/serial/by-id/usb-1a86_USB2.0-Ser_-if00-port0 115200
screen -S esp8266 -X stuff 'node.restart()\n'
screen -r esp8266
