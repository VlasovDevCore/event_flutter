-- Ответ на сообщение в чате события
ALTER TABLE event_messages
    ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES event_messages (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_event_messages_reply_to ON event_messages (reply_to_id);
