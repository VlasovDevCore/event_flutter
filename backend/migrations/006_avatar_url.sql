-- Avatar image URL/path (served by backend)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

