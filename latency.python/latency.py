#!/usr/bin/env python
from forker import *
from typing import List
import os
import sys
import select
import random
import time
import struct
import numpy
import psycopg2
import re
import socket
import json

assert sys.version_info >= (3, 4)


def main(forking=True):
    port = 1234
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    os.chdir("../latency.static")
    for sock, addr in listen(port=port, forking=forking):
        try:
            request = Request(sock=sock, remote_ip=addr[0], listening_port=port)
            print(request.requested_path)
            if request.headers.get("upgrade") == "websocket":
                play_ping_pong(sock, request)
            else:
                if request.requested_path == "/xhr/hit":
                    register_hit(request=request, sock=sock)
                elif request.requested_path == "/xhr/geo":
                    on_geo(request=request, sock=sock)
                else:
                    sock.sendall(request.serve())
                    sock.close()
        except (ConnectionAbortedError, TimeoutError, ValueError, StopIteration):
            pass
        finally:
            sock.close()
            if forking:
                sys.exit(0)


def register_hit(request: Request, sock: socket.socket) -> bytes:
    print("register_hit body=>%r" % request.body)
    out = bytearray(b'HTTP/1.0 200 OK\r\n')
    trail = request.cookies.get("trail")
    first_hit = False
    if not trail:
        trail = random.randint(WEB_MIN, WEB_MAX)
        # expires= path=/
        out += ("Set-Cookie: trail=%d; Expires=Wed, 29 Oct 2037 05:46:09 UTC; Path=/;" % trail).encode()
        if "x5e.com" in request.headers.get("host", "").lower():
            out += b" domain=x5e.com;"
        out += b'\r\n'
        first_hit = True
    out += b'\r\n'
    hit_id = random.randint(WEB_MIN, WEB_MAX)
    out += str(hit_id).encode()
    sock.sendall(out)
    sock.close()
    fields = [hit_id, trail, first_hit, request.remote_ip, request.rdns(),
              json.dumps(request.headers), request.body.decode()]
    bits = ",".join(["%s" for f in fields])
    query = "insert into latency.hits (hit_id, trail, first_hit, remote_ip, rdns, headers, payload) values (%s)" % bits
    with get_con() as con:
        with con.cursor() as cur:
            cur.execute(query, fields)


def on_geo(request: Request, sock: socket.socket):
    sock.sendall(b"<pre>" + bytes(request) + b"</pre>")
    sock.close()


def record_observations(hit_id: int, observations: List) -> None:
    observations.sort()

    def p(x):
        n = int(round(x * (len(observations) - 1) / 100.0))
        return observations[n]

    vals = [int(hit_id), len(observations),
            numpy.mean(observations), numpy.std(observations)]
    for i in [0, 1, 5, 25, 50, 75, 95, 99, 100]:
        vals.append(p(i))
    bits = ",".join(["%s" for f in vals])
    query = "insert into latency.latencies values (%s);" % bits
    with get_con() as con:
        with con.cursor() as cur:
            cur.execute(query, vals)
    sys.stderr.write("%d observations for %s\n" % (len(observations), hit_id))


def play_ping_pong(sock: socket.socket, request: Request):
    hit_id = int(request.query_string)
    if not (WEB_MIN <= hit_id <= WEB_MAX):
        sock.sendall(b"HTTP/1.0 400 USER_ERROR\r\n\r\n")
        sock.close()
        return
    wss = WebSocketServer(sock=sock, request=request)
    observations = list()
    try:
        for i in range(201):
            msg = hex(random.randint(WEB_MIN, WEB_MAX)).encode()
            wss.send(msg, kind=TEXT)
            started = time.time()
            selected = select.select([wss], [], [], 10)
            ended = time.time()
            if not selected[0]:
                raise TimeoutError()
            packets = wss.recvall()
            if not len(packets) == 1:
                raise ConnectionAbortedError()
            if packets[0] != msg:
                raise ValueError()
            delay = ended - started
            if i:  # ignore first delay
                observations.append(delay)
                packed = struct.pack("d",delay)
                wss.send(packed, kind=BIN)
            time.sleep(0.1)
    finally:
        wss.close()
        if len(observations) > 2 and re.fullmatch(r"\d+", request.query_string):
            record_observations(hit_id, observations)


def get_con():
    return psycopg2.connect(
        host="localhost",
        database="latency",
        user="doorman",
        password="doorman",
        port=5432)

if __name__ == "__main__":
    main(forking=("nofork" not in sys.argv))
