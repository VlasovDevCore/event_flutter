-- Добавляем статус пользователя (по умолчанию 1)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS status SMALLINT NOT NULL DEFAULT 1;

