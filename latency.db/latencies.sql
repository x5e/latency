create table if not exists latencies (
    hit BIGINT PRIMARY KEY,
    nobs int,
    mean real,
    stdev real,

    p00 real,
    p01 real,
    p05 real,
    p25 real,
    p50 real,
    p75 real,
    p95 real,
    p99 real,
    top real
);
