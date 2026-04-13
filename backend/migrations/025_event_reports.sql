-- Event reports (complaints)
CREATE TABLE IF NOT EXISTS event_reports (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id         UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    category         TEXT NOT NULL,
    message          TEXT NOT NULL DEFAULT '',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_reports_event
  ON event_reports (event_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_event_reports_reporter
  ON event_reports (reporter_user_id, created_at DESC);

