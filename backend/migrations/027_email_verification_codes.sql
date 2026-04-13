-- Email verification codes (OTP)
CREATE TABLE IF NOT EXISTS email_verification_codes (
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code       TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_verification_codes_user
  ON email_verification_codes (user_id, created_at DESC);

