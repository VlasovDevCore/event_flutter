-- Добавляем картинку события
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS image_url TEXT NULL;

