-- Убраны настраиваемые цвет/иконка плейсхолдера аватара (остаётся только avatar_url)
ALTER TABLE users
  DROP COLUMN IF EXISTS avatar_color_value,
  DROP COLUMN IF EXISTS avatar_icon_code;
