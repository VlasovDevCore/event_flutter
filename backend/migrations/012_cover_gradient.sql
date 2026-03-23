-- Градиент обложки профиля: массив из 3 hex-цветов (#RRGGBB), JSONB
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS cover_gradient_colors JSONB DEFAULT NULL;
