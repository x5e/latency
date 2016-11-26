create table if not exists latency.hits (
    ts          TIMESTAMPTZ DEFAULT now(),
    hit_id      BIGINT PRIMARY KEY,
    trail       BIGINT NOT NULL,
    first_hit   BOOLEAN NOT NULL,
    remote_ip   TEXT NOT NULL,
    rdns        TEXT NULL,
    headers     JSONB NOT NULL,
    payload     JSONB NOT NULL
);
