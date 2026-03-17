-- Profile fields for users
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS display_name TEXT,
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS birth_date DATE,
  ADD COLUMN IF NOT EXISTS gender TEXT,
  ADD COLUMN IF NOT EXISTS avatar_color_value BIGINT,
  ADD COLUMN IF NOT EXISTS avatar_icon_code BIGINT;

-- Optional constraints (soft): keep gender free-form for now.

