-- Заявки в друзья и список друзей
-- from_user_id отправил заявку to_user_id; status: pending | accepted
CREATE TABLE IF NOT EXISTS friend_requests (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (from_user_id, to_user_id)
);

CREATE INDEX IF NOT EXISTS idx_friend_requests_to ON friend_requests (to_user_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_from ON friend_requests (from_user_id);
