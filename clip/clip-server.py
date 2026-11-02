import multiprocessing.connection
import os
import subprocess
import sys

path = sys.argv[1]

try:
    os.unlink(path)
except FileNotFoundError:
    pass

with multiprocessing.connection.Listener(path, family='AF_UNIX') as listener:
    while True:
        with listener.accept() as conn:
            msg = conn.recv_bytes()

        subprocess.run(['xclip', '-selection', 'clipboard', '-target', 'UTF8_STRING'],
                       input=msg, check=False)
