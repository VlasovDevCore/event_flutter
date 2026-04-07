-- Mute push-уведомлений для личных чатов (на уровне отправителя)
-- user_id: получатель push, peer_user_id: собеседник (отправитель сообщений)
CREATE TABLE IF NOT EXISTS user_direct_chat_mutes (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  peer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  muted_until TIMESTAMPTZ NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, peer_user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_direct_chat_mutes_user_id
  ON user_direct_chat_mutes (user_id);

CREATE INDEX IF NOT EXISTS idx_user_direct_chat_mutes_peer_user_id
  ON user_direct_chat_mutes (peer_user_id);

