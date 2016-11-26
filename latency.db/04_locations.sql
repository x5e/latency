create table latency.locations (
    ts          TIMESTAMPTZ default now(),
    hit         BIGINT PRIMARY KEY,
    latitude    DOUBLE PRECISION,
    longitude   DOUBLE PRECISION,
    accuracy    DOUBLE PRECISION,
    altitude    DOUBLE PRECISION,
    alt_acc     DOUBLE PRECISION,
    heading     DOUBLE PRECISION,
    speed       DOUBLE PRECISION,
    acquired    DOUBLE PRECISION
);
