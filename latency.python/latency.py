#!/usr/bin/env python
from forker import *
from typing import List
import os
import sys
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
    query = "insert into latency.hits (id, trail, first_hit, remote_ip, rdns, headers, payload) values (%s)" % bits
    with get_con() as con:
        with con.cursor() as cur:
            cur.execute(query, fields)


def on_geo(request: Request, sock: socket.socket):
    doubles = struct.unpack("d" * 10, request.body)

    lat = doubles[1]
    lon = doubles[2]

    query = """
    select round(3961 * 2 * atan2(sqrt(a),sqrt(1-a))) as d,
    substring(rdns,'[\d\w]+.[\d\w]+$') as isp,
    (case
        when p95 < 50 then 'great'
        when p95 < 100 then 'good'
        when p95 < 200 then 'meh'
        when p95 < 400 then 'poor'
        else 'horrible' end) as quality,
    p50,p95,p99,mean,stdev
    from (
        select *
    ,power(sin(dlat/2),2) + (cos(lat1)*cos(lat2)*power(sin(dlon/2),2)) as a
        from (
        select
        %s as lat1,
        %s as lon1,
        %s - latitude as dlat,
        %s - longitude as dlon,
        longitude as lon2 ,latitude as lat2,rdns
        ,round(mean*1000) as mean,round(stdev*1000) as stdev
        ,round(p50*1000) as p50,round(p95*1000) as p95 ,round(p99*1000) as p99
        ,row_number() over (partition by trail order by hits.ts desc) as rn
        from latency.hits as hits
        join latency.latencies as t on hits.id = t.hit
        join latency.locations as o on hits.id = o.hit
        ) as i
        where rn = 1
    ) as j
    order by 1 limit 30;
    """
    mobile = False
    if request.query_string == "mobile":
        mobile = True

    with get_con() as con:
        with con.cursor() as cur:
            cur.execute(query, [lat, lon, lat, lon])
            rows = cur.fetchall()
        out = """
        <table>
        <tr><th>miles</th><th>ISP</th><th>quality</th><th>med.</th>
        """
        if not mobile:
            out += "<th>95th</th><th>99th</th><th>mean</th><th>stdev</th></tr>"
        for row in rows:
            out += "<tr>"
            for i, field in enumerate(row):
                if i <= 3 or not mobile:
                    if isinstance(field, float):
                        out += "<td>%d</td>" % field
                    else:
                        out += "<td>%s</td>" % field
            out += "</tr>"
        out += "</table>"
        sock.sendall(out.encode())
        sock.close()

        with con.cursor() as cur:
            query = """
                insert into latency.locations
            (hit,latitude,longitude,accuracy,altitude,alt_acc,heading,speed,acquired)
                values (%s, %s,%s,%s,%s,%s,%s,%s,%s);
            """
            vals = list(doubles[0:9])
            cur.execute(query, vals)


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
            packets = wss.recvall()
            ended = time.time()
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
