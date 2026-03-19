-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- NOTE: PostGIS не установлен в вашей БД, поэтому geom/GEOGRAPHY временно убраны.
-- Когда установите PostGIS, можно добавить:
-- CREATE EXTENSION IF NOT EXISTS postgis;

-- Users (простая таблица под авторизацию)
CREATE TABLE IF NOT EXISTS users (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email        TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    status       SMALLINT NOT NULL DEFAULT 1,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Events (события на карте)
CREATE TABLE IF NOT EXISTS events (
    id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title              TEXT NOT NULL,
    description        TEXT NOT NULL DEFAULT '',
    lat                DOUBLE PRECISION NOT NULL,
    lon                DOUBLE PRECISION NOT NULL,
    marker_color_value BIGINT NOT NULL,
    marker_icon_code   BIGINT NOT NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    ends_at            TIMESTAMPTZ,  -- до какой даты актуально (макс. неделя вперёд)
    created_by         UUID REFERENCES users(id) ON DELETE SET NULL
);

-- Когда включите PostGIS и добавите колонку geom, создайте индекс:
-- CREATE INDEX IF NOT EXISTS idx_events_geom ON events USING GIST (geom);

-- RSVP по пользователям (кто придёт / не придёт)
-- status: 1 = приду, -1 = не приду
CREATE TABLE IF NOT EXISTS event_rsvp (
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status   SMALLINT NOT NULL CHECK (status IN (-1, 1)),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (event_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_event_rsvp_event ON event_rsvp (event_id);
CREATE INDEX IF NOT EXISTS idx_event_rsvp_user  ON event_rsvp (user_id);

-- Сообщения чата по событиям
CREATE TABLE IF NOT EXISTS event_messages (
    id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id   UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    text       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_event_messages_event_created_at
    ON event_messages (event_id, created_at DESC);

