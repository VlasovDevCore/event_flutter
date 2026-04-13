-- User reports (complaints)
CREATE TABLE IF NOT EXISTS user_reports (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reported_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category         TEXT NOT NULL,
    message          TEXT NOT NULL DEFAULT '',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_reports_reported
  ON user_reports (reported_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_reports_reporter
  ON user_reports (reporter_user_id, created_at DESC);

