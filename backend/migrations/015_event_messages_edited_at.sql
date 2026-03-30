-- Время последнего редактирования текста сообщения (NULL = не редактировали)
ALTER TABLE event_messages
    ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ NULL;
