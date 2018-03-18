#!/usr/bin/env python3.6
import requests
import sys
import datetime
import time
import boto3
client = boto3.client("lambda")

times = list()
for i in range(100):
    start = datetime.datetime.now()
    r = client.invoke(FunctionName="digest", Payload=b'{"x":"hello"}')
    body = r["Payload"].read()
    print(body)
    elapsed = datetime.datetime.now() - start
    if i:
        times.append(elapsed)
    print(i, elapsed, file=sys.stderr)
    print()
    time.sleep(0.1)

show = False or (lambda x: print(x, file=sys.stderr))
times.sort()
N = len(times)
show("")
show("N = %s" % N)
show("(HTTP[S]) round-trip times in milliseconds:")
show("")
show("min   : %s" % times[0])
show(" 5th  : %s" % times[N*5//100])
show("25th  : %s" % times[N//4])
show("median: %s" % times[N//2])
show("75th  : %s" % times[N*3//4])
show("95th  : %s" % times[N*95//100])
show("99th  : %s" % times[N*99//100])
show("max   : %s" % times[-1])
show("")
