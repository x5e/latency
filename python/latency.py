#!/usr/local/bin/python
import os
import sys
import select
import random
import time
import socket
import struct
import forker
import numpy
import psycopg2
sys.path.append("../modules")

WEB_MIN = 0x10000000000000
WEB_MAX = 0x1fffffffffffff

port = int(sys.argv[1]) if sys.argv[1:] else 9999
for sock,addr,forkId in forker.listen(port=port): break
#print "======= forked ======="
wss = forker.WebSocketServer(sock)
path,hitId = wss.loc.split("?",1)
assert int(hitId) >= 0x10000000000000, hitId
assert int(hitId) <= 0x20000000000000, hitId
observations = list()
try:
    for i in range(201):
        msg = hex(random.randint(WEB_MIN,WEB_MAX))
        wss.send(msg,kind=forker.TEXT)
        started = time.time()
        x,y,z = select.select([wss],[],[],10)
        ended = time.time()
        assert x,"timeout"
        packets = wss.recvall()
        assert len(packets) == 1,packets
        assert packets[0] == msg,packets[0]
        delay = ended - started
        if i: # ignore first delay
            observations.append(delay)
            packed = struct.pack("d",delay)
            wss.send(packed,kind=forker.BIN)
        time.sleep(0.1)
    wss.close()
finally:
    if len(observations) < 2: raise Exception("too few exceptions")

    import doorman

    observations.sort()
    def p(x):
        n = int(round(x * (len(observations)-1) / 100.0))
        return observations[n]
    vals = [int(hitId),len(observations),
            numpy.mean(observations),numpy.std(observations)]
    for i in [0,1,5,25,50,75,95,99,100]:
        vals.append(p(i))
    query = """
        insert into log.latencies
        values (
            %s,%s,%s,%s,
            %s,%s,%s,%s,%s,
            %s,%s,%s,%s);
    """
    doorman.cur.execute(query,vals)
    doorman.con.commit()
    sys.stderr.write("%d observations for %s from %s\n" % (len(observations),hitId,addr[0]))
