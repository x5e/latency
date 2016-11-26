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

assert sys.version_info >= (3, 4)


def main(forking=True):
    port = 1234
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    os.chdir("static")
    for sock, addr in listen(port=port, forking=forking):
        try:
            request = Request(sock=sock, remote_ip=addr[0], listening_port=port)
            print(request.requested_path)
            if request.requested_path == "/web_socket":
                play_ping_pong(sock, request)
            else:
                if request.requested_path == "/hit":
                    response = register_hit(request)
                elif request.requested_path == "/geo":
                    response = on_geo(request)
                else:
                    response = request.serve()
                sock.sendall(response)
        except (ConnectionAbortedError, TimeoutError, ValueError):
            pass
        finally:
            sock.close()
            if forking:
                sys.exit(0)


def register_hit(request: Request) -> bytes:
    header = b'HTTP/1.0 200 OK\r\n\r\n'
    hit_id = random.randint(WEB_MIN, WEB_MAX)
    as_str = str(hit_id)
    as_bytes = as_str.encode()
    return header + as_bytes 
    

def on_geo(request: Request) -> bytes:
    return bytes(request)


def record_observations(hit_id: int, observations: List) -> None:
    observations.sort()

    def p(x):
        n = int(round(x * (len(observations) - 1) / 100.0))
        return observations[n]

    vals = [int(hit_id), len(observations),
            numpy.mean(observations), numpy.std(observations)]
    for i in [0, 1, 5, 25, 50, 75, 95, 99, 100]:
        vals.append(p(i))
    query = """
        insert into log.latencies
        values (
            %s,%s,%s,%s,
            %s,%s,%s,%s,%s,
            %s,%s,%s,%s);
    """
    doorman.cur.execute(query, vals)
    doorman.con.commit()
    sys.stderr.write("%d observations for %s from %s\n" % (len(observations), hit_id, addr[0]))


def play_ping_pong(sock: socket.socket, request: Request):
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
            record_observations(int(request.query_string), observations)


def get_con():
    return psycopg2.connect(host="db.x5e.com", database="latency", user="latency")

if __name__ == "__main__":
    main(forking=("nofork" not in sys.argv))
