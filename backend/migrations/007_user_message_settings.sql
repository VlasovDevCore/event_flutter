-- Allow direct messages from non-friends
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS allow_messages_from_non_friends BOOLEAN NOT NULL DEFAULT true;

