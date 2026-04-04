-- Прочитанность личных сообщений (как event_message_views)
CREATE TABLE IF NOT EXISTS direct_message_views (
    message_id UUID NOT NULL REFERENCES direct_messages(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    viewed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_direct_message_views_user_viewed_at
    ON direct_message_views (user_id, viewed_at DESC);

CREATE INDEX IF NOT EXISTS idx_direct_message_views_message_viewed_at
    ON direct_message_views (message_id, viewed_at DESC);
