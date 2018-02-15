"use strict";
var points = [];
var hit_id = null;
var api = window.location.href.replace("www", "api");

function register_hit() {
    var payload = {};
    payload.referrer = document.referrer;
    payload.innerWidth = window.innerWidth || document.documentElement.clientWidth || document.body.clientWidth || null;
    payload.innerHeight = window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight || null;
    payload.availHeight = screen.availHeight;
    payload.availWidth = screen.availWidth;
    payload.screenWidth = screen.width;
    payload.screenHeight = screen.height;
    payload.userAgent = navigator.userAgent;
    payload.href = window.location.href;
    whack(api + "xhr/hit", JSON.stringify(payload), main, putMsg)
}

function whack(url, data, cb, on_err, on_timeout) {
    if (typeof(data) !== "string" && data && ! data.byteLength) {
        data = JSON.stringify(data);
    }
    var request = new XMLHttpRequest();
    request.timeout = 10000;
    request.ontimeout = function () {
        if (on_timeout) return on_timeout();
        if (on_err) return on_err("timeout",100);
        console.error("timeout hitting: " + url);
    };
    request.onreadystatechange = function() {
        if (request.readyState !== 4) return;
        if (request.status === 200) {
            if (cb) cb(request.responseText);
        } else {
            if (on_err) on_err(request.responseText,request.status);
        }
    };
    request.open("POST", url, true);
    request.send(data || "");
}

function println(x) {
    document.getElementById("foo").innerHTML += (x + "\n");
}

function putMsg(x) {
    document.getElementById("msg").innerHTML = x;
}

function showPosition(position) {
    console.log("showPosition");
    document.getElementById("wait").style.display = "none";
    var ab = new ArrayBuffer(80);
    var fa = new Float64Array(ab);
    var src = [
        hit_id,
        position.coords.latitude,
        position.coords.longitude,
        position.coords.accuracy,
        position.coords.altitude,
        position.coords.altitudeAccuracy,
        position.coords.heading,
        position.coords.speed,
        position.timestamp
    ];
    for (var i=0;i<10;i++) {
        if (src[i] === null)
            fa[i] = NaN;
        else
            fa[i] = src[i];
    }
    var cb = function (resp) {
        document.getElementById("tt").innerHTML = resp;
    };
    var err = function(what) {
        println("error");
        println(what);
    };
    var kind = "desktop";
    if (window.innerWidth <= 480) kind = "mobile";
    whack(api + "xhr/geo?" + kind,ab,cb,err);
}

function showError(error) {
    console.log("showError");
    switch(error.code) {
        case error.PERMISSION_DENIED:
            println("User denied the request for Geolocation.");
            break;
        case error.POSITION_UNAVAILABLE:
            println("Location information is unavailable.");
            break;
        case error.TIMEOUT:
            println("The request to get user location timed out.");
            break;
        case error.UNKNOWN_ERROR:
            println("An unknown error occurred.");
            break;
    }
}

function compare(x) {
    document.getElementById("ask").style.display = "none";
    document.getElementById("wait").style.display = "block";
    navigator.geolocation.getCurrentPosition(showPosition, showError);
}

function format(x) {
    var suffix;
    if (x < 1) {
        suffix = " milliseconds";
        x = x * 1000;
    } else {
        suffix = " seconds";
    }
    
    var y = x.toFixed(1);
    while (y.length < 6) {
        y = " " + y;
    }
    return(y + suffix);
}

function percentile(p) {
    var f = p / 100.0;
    var n = Math.round((points.length - 1) * f);
    return points[n];
}

function observe(x) {
    var y = format(x);
    var obs = document.getElementById("observations");
    obs.innerHTML = obs.innerHTML + "\n" + y;
    obs.scrollTop = obs.scrollHeight;
    points.push(x);
    points.sort(function(a,b) {return a-b;});
    var z = percentile(95)*1000;
    var q = document.getElementById("quality");
    while (true) {
        q.innerHTML = z;
        if (z < 50)  { q.innerHTML = "quality: excellent"; break; }
        if (z < 100)  { q.innerHTML = "quality: good"; break; }
        if (z < 200) { q.innerHTML = "quality: meh"; break; }
        if (z < 400) { q.innerHTML = "quality: poor"; break; }
        q.innerHTML = "quality: horrible";
        if (z >= 0)
            break;
    }
    var tx = 0;
    var txx = 0;
    for ( var i = 0; i < points.length; i++) {
        tx += points[i];
        txx += points[i] * points[i];
    }
    var mean = tx/points.length;
    var exx = txx/points.length;
    var sd = Math.sqrt(exx - (mean*mean));
    var summary = document.getElementById("summary");
    var max = points[points.length - 1];
    summary.innerHTML = "";
    var nObs = points.length.toFixed(0);
    while (nObs.length < 3) nObs = " " + nObs;
    summary.innerHTML += "            " + nObs + " observations\n";
    summary.innerHTML += "\n";
    summary.innerHTML += "    min: " + format(percentile(0)) + "\n";
    summary.innerHTML += "    1st: " + format(percentile(1)) + "\n";
    summary.innerHTML += "    5th: " + format(percentile(5)) + "\n";
    summary.innerHTML += "   25th: " + format(percentile(25)) + "\n";
    summary.innerHTML += " median: " + format(percentile(50)) + "\n";
    summary.innerHTML += "   75th: " + format(percentile(75)) + "\n";
    summary.innerHTML += "   95th: " + format(percentile(95)) + "\n";
    summary.innerHTML += "   99th: " + format(percentile(99)) + "\n";
    summary.innerHTML += "    max: " + format(percentile(100)) + "\n";
    summary.innerHTML += "\n";
    summary.innerHTML += "   mean: " + format(mean) + "\n";
    summary.innerHTML += "  stdev: " + format(sd) + "\n";
}

function str2doubles(x) {
    var dv = new Float64Array(x);
    var out = [];
    for (var i=0;i<dv.length;i++) {out.push(dv[i]);}
    return out;
}

function main(arg) {
    hit_id = arg;
    var target = api.replace("http", "ws") + "websocket?" + hit_id;
    console.log(target);
    // target = "ws://localhost:4321/";
    var websocket = new WebSocket(target);
    websocket.binaryType = "arraybuffer";
    websocket.onclose = function (evt) {
        var obs = document.getElementById("observations");
        obs.innerHTML = obs.innerHTML + "\n         done!";
        obs.scrollTop = obs.scrollHeight;
    };
    websocket.onmessage = function (evt) {
        try {
            if (typeof(evt.data) === "string") {
                if (evt.data.indexOf('0x') === 0) {
                    websocket.send(evt.data);
                }
            } else {
                var vals = str2doubles(evt.data);
                var latency = vals.shift();
                observe(latency);
            }
        } catch (e) {
            println("exception: " + e);
        }
    };
    websocket.onerror = function (evt) {
        println("onerror:" + evt.data);
    };
    websocket.onopen = function (evt) {
        //println("websocket onopen");
    };
    var foo = document.getElementById("foo");
    if (!("geolocation" in navigator)) {
        document.getElementById("ask").style.display = "none";
    }
}
