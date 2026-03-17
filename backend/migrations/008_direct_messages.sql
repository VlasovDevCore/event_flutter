-- Direct messages between users
CREATE TABLE IF NOT EXISTS direct_messages (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    text         TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_direct_messages_pair_created_at
  ON direct_messages (from_user_id, to_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_direct_messages_to_created_at
  ON direct_messages (to_user_id, created_at DESC);

