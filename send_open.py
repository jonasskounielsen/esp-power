import socket
import write_message

command = "open relay"

message = write_message.create_message(command)

IP = "192.168.1.190"
PORT = 10727

socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
socket.connect((IP, PORT))
socket.sendall(message.encode("utf-8"))
