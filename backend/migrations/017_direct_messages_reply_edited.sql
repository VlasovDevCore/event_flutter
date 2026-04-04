-- Ответ и правки в личных сообщениях
ALTER TABLE direct_messages
    ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES direct_messages (id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_direct_messages_reply_to ON direct_messages (reply_to_id);
