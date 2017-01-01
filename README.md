# latency

## Protocol
Clients will first make an XmlHttpRequest to `/hit`, in the process receiving a hit id,
which will be between:
```
>>> hex(forker.WEB_MIN)
'0x10000000000000'
>>> hex(forker.WEB_MAX)
'0x1fffffffffffff'
```

The client may then open a websocket connection to `/websocket` with the 
hit id as the get query string.  The special value of `9007199254740992`
(aka `0x20000000000000`) may be used for testing.  Thus the full testing
URL would be:
```
wss://latency.x5e.qa/websocket?9007199254740992
```

Once connected, the websocket client will receive a number of text messages,
which it must should back to the server exactly as-is.  The server uses the
transit time of these messages (server to client to server) as the basis
of measurement, then sends a binary message with the round trip time,
encoded as a IEEE double.
