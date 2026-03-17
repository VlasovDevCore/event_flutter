-- Username/login for users
-- Nullable to keep backward compatibility for existing users
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS username TEXT;

-- Ensure uniqueness when set
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_username
  ON users (username)
  WHERE username IS NOT NULL;

