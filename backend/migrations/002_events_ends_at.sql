-- Дата окончания события (до какой даты актуально). Макс. неделя вперёд при создании.
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS ends_at TIMESTAMPTZ;

-- Для уже существующих строк: считаем событие актуальным до created_at + 7 дней
UPDATE events
  SET ends_at = created_at + interval '7 days'
  WHERE ends_at IS NULL;
