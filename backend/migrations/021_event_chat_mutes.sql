-- Mute push-уведомлений для чатов событий
-- user_id: получатель push, event_id: событие
CREATE TABLE IF NOT EXISTS user_event_chat_mutes (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  muted_until TIMESTAMPTZ NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, event_id)
);

CREATE INDEX IF NOT EXISTS idx_user_event_chat_mutes_user_id
  ON user_event_chat_mutes (user_id);

CREATE INDEX IF NOT EXISTS idx_user_event_chat_mutes_event_id
  ON user_event_chat_mutes (event_id);

