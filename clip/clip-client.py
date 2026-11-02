#!/usr/bin/env python3

import multiprocessing.connection
import sys

path = sys.argv[1]
msg = sys.stdin.buffer.read()

with multiprocessing.connection.Client(path, family='AF_UNIX') as conn:
    conn.send_bytes(msg)
