import hmac
import hashlib
import time

def create_message(command: str):
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

    return f"{command}\n{timestamp}\n{signature}".format(command = command, timestamp = timestamp, signature = signature)

if __name__ == "__main__":
    command = input()
    print(create_message(command))
