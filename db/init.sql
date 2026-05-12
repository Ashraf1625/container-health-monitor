-- Container Health Monitor — initial schema
-- This file runs automatically on first start via docker-entrypoint-initdb.d

CREATE TABLE IF NOT EXISTS events (
    id             SERIAL PRIMARY KEY,
    container_name TEXT        NOT NULL,
    event_type     TEXT        NOT NULL,   -- STOP | RESTART | INFO | ALERT
    message        TEXT        NOT NULL,
    timestamp      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_events_container  ON events (container_name);
CREATE INDEX IF NOT EXISTS idx_events_timestamp  ON events (timestamp DESC);

-- Seed a welcome event so the log is never empty on first visit
INSERT INTO events (container_name, event_type, message)
VALUES ('system', 'INFO', 'Container Health Monitor started — database initialised.');
