import hmac
import hashlib
import time
import sys

command = input()

hmac_key = None
with open("secrets.lua", "r") as secret_file:
    for line in secret_file:
        name, value = [value.strip() for value in line.split("=")]
        if name == "HMAC_KEY":
            hmac_key = value[1:65]

if hmac_key is None:
    raise RuntimeError("no hmac key in secrets file")

timestamp = int(time.time())

data = f"{command}{timestamp}"

signature = hmac.new(hmac_key.encode("utf-8"), data.encode("utf-8"), hashlib.sha256).hexdigest()

print('''\
{command}
{timestamp}
{signature}\
'''.format(command = command, timestamp = timestamp, signature = signature))
