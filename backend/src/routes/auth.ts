import { Router } from 'express';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../middleware/auth';
import { getPublicBackendBaseUrl, sendEmail } from '../services/mailer';
import { randomCoverGradientColors } from '../utils/coverGradientPresets';

const router = Router();

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function isValidEmailFormat(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function validatePassword(password: string): string | null {
  const p = password;
  if (p.length < 8) return 'Пароль: минимум 8 символов';
  // Only ASCII visible chars (latin letters, digits, symbols).
  if (!/^[\x21-\x7E]+$/.test(p)) {
    return 'Пароль: только латиница, цифры и символы (без пробелов и кириллицы)';
  }
  if (!/[A-Za-z]/.test(p)) return 'Пароль: добавьте английскую букву';
  if (!/[0-9]/.test(p)) return 'Пароль: добавьте цифру';
  if (!/[^A-Za-z0-9]/.test(p)) return 'Пароль: добавьте спецсимвол';
  return null;
}

function makeEmailVerificationToken(): string {
  return crypto.randomBytes(32).toString('hex');
}

async function createAndSendVerificationEmail(params: {
  userId: string;
  email: string;
}): Promise<void> {
  const token = makeEmailVerificationToken();
  const expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 7); // 7 days

  await pool.query(
    `
    INSERT INTO email_verifications (token, user_id, expires_at)
    VALUES ($1, $2, $3)
    `,
    [token, params.userId, expiresAt],
  );

  const base = getPublicBackendBaseUrl();
  const link = `${base}/auth/verify-email?token=${encodeURIComponent(token)}`;
  const subject = 'Подтверждение почты';
  const text = `Подтвердите почту, перейдя по ссылке:\n${link}\n\nЕсли вы не регистрировались, просто игнорируйте это письмо.`;

  await sendEmail({
    to: params.email,
    subject,
    text,
    html: `
      <div style="font-family:Arial,sans-serif;line-height:1.4">
        <h2>Подтверждение почты</h2>
        <p>Нажмите, чтобы подтвердить email:</p>
        <p><a href="${link}">${link}</a></p>
        <p style="color:#777">Если вы не регистрировались, просто игнорируйте это письмо.</p>
      </div>
    `,
  });
}

function makeEmailVerificationCode(): string {
  // 6 digits
  const n = crypto.randomInt(0, 1000000);
  return String(n).padStart(6, '0');
}

async function createAndSendVerificationCode(params: {
  userId: string;
  email: string;
}): Promise<void> {
  const code = makeEmailVerificationCode();
  const expiresAt = new Date(Date.now() + 1000 * 60 * 10); // 10 min

  await pool.query(
    `
    INSERT INTO email_verification_codes (user_id, code, expires_at)
    VALUES ($1, $2, $3)
    `,
    [params.userId, code, expiresAt],
  );

  const subject = 'Код подтверждения почты';
  const text = `Ваш код подтверждения: ${code}\n\nКод действует 10 минут.`;

  await sendEmail({
    to: params.email,
    subject,
    text,
    html: `
      <div style="font-family:Arial,sans-serif;line-height:1.4">
        <h2>Подтверждение почты</h2>
        <p>Ваш код:</p>
        <p style="font-size:24px;font-weight:700;letter-spacing:2px">${code}</p>
        <p style="color:#777">Код действует 10 минут.</p>
      </div>
    `,
  });
}

router.get('/check-email', async (req, res) => {
  const email = typeof req.query.email === 'string' ? req.query.email.trim() : '';
  const normalized = normalizeEmail(email);
  if (!normalized || !isValidEmailFormat(normalized)) {
    return res.status(400).json({ error: 'Некорректный email' });
  }

  const client = await pool.connect();
  try {
    const existing = await client.query('SELECT 1 FROM users WHERE email = $1', [normalized]);
    if ((existing.rowCount ?? 0) > 0) {
      return res.status(409).json({ error: 'Этот email уже зарегистрирован' });
    }
    return res.json({ available: true });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.post('/register', async (req, res) => {
  const { email, password, username, displayName } = req.body as {
    email?: string;
    password?: string;
    username?: string;
    displayName?: string;
  };
  if (!email || !password) {
    return res.status(400).json({ error: 'Укажите email и пароль' });
  }
  const normalizedEmail = normalizeEmail(email);
  if (!isValidEmailFormat(normalizedEmail)) {
    return res.status(400).json({ error: 'Некорректный email' });
  }
  const passError = validatePassword(password);
  if (passError) {
    return res.status(400).json({ error: passError });
  }
  const normalizedUsername = typeof username === 'string' ? username.trim() : '';
  const normalizedDisplayName = typeof displayName === 'string' ? displayName.trim() : '';

  if (normalizedUsername.length < 3 || normalizedUsername.length > 24) {
    return res.status(400).json({ error: 'Логин: 3–24 символа' });
  }
  if (!/^[a-zA-Z0-9_]+$/.test(normalizedUsername)) {
    return res.status(400).json({ error: 'Логин: только латиница, цифры и _' });
  }
  if (normalizedDisplayName.length < 1 || normalizedDisplayName.length > 40) {
    return res.status(400).json({ error: 'Имя: 1–40 символов' });
  }

  const client = await pool.connect();
  try {
    const existing = await client.query(
      'SELECT id FROM users WHERE email = $1',
      [normalizedEmail],
    );
    if (existing.rowCount && existing.rowCount > 0) {
      return res.status(409).json({ error: 'Этот email уже зарегистрирован' });
    }

    const existingUsername = await client.query(
      'SELECT 1 FROM users WHERE username = $1',
      [normalizedUsername],
    );
    if (existingUsername.rowCount && existingUsername.rowCount > 0) {
      return res.status(409).json({ error: 'Этот логин уже занят' });
    }

    const hash = await bcrypt.hash(password, 10);
    const coverGradient = randomCoverGradientColors();
    const insert = await client.query(
      `
      INSERT INTO users (email, password_hash, username, display_name, status, cover_gradient_colors)
      VALUES ($1, $2, $3, $4, 0, $5::jsonb)
      RETURNING id, email, username, status, created_at, cover_gradient_colors
      `,
      [normalizedEmail, hash, normalizedUsername, normalizedDisplayName, JSON.stringify(coverGradient)],
    );

    const user = insert.rows[0];
    const token = jwt.sign({ sub: user.id, email: user.email }, JWT_SECRET, {
      expiresIn: '7d',
    });

    // Отправляем письмо, но не блокируем регистрацию.
    try {
      await createAndSendVerificationEmail({ userId: user.id, email: user.email });
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn('Verification email send failed:', e);
    }

    return res.status(201).json({ user, token });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.post('/login', async (req, res) => {
  const { email, password } = req.body as { email?: string; password?: string };
  if (!email || !password) {
    return res.status(400).json({ error: 'Invalid email or password' });
  }

  const client = await pool.connect();
  try {
    const result = await client.query(
      'SELECT id, email, username, status, password_hash, created_at FROM users WHERE email = $1',
      [normalizeEmail(email)],
    );
    if (result.rowCount === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign({ sub: user.id, email: user.email }, JWT_SECRET, {
      expiresIn: '7d',
    });

    return res.json({
      user: {
        id: user.id,
        email: user.email,
        username: user.username ?? null,
        status: user.status,
        created_at: user.created_at,
      },
      token,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.post('/send-verification-code', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const r = await client.query('SELECT email, status FROM users WHERE id = $1', [me]);
    if (r.rowCount === 0) return res.status(404).json({ error: 'User not found' });
    const email = String(r.rows[0].email ?? '').trim();
    const status = Number(r.rows[0].status ?? 1);
    if (!email) return res.status(400).json({ error: 'Email not found' });
    if (status === 1) return res.json({ ok: true, already_verified: true });

    // Basic throttle: don't send too often (30s)
    const last = await client.query(
      `
      SELECT created_at
      FROM email_verification_codes
      WHERE user_id = $1
      ORDER BY created_at DESC
      LIMIT 1
      `,
      [me],
    );
    const lastAt = (last.rows[0]?.created_at as Date | undefined) ?? undefined;
    if (lastAt && Date.now() - new Date(lastAt).getTime() < 30_000) {
      return res.status(429).json({ error: 'Подождите немного перед повторной отправкой' });
    }

    await createAndSendVerificationCode({ userId: me, email });
    return res.json({ ok: true });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.post('/verify-email-code', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  const { code } = req.body as { code?: string };
  const normalized = typeof code === 'string' ? code.trim() : '';
  if (!/^\d{6}$/.test(normalized)) {
    return res.status(400).json({ error: 'Введите 6-значный код' });
  }

  const client = await pool.connect();
  try {
    const r = await client.query('SELECT status FROM users WHERE id = $1', [me]);
    if (r.rowCount === 0) return res.status(404).json({ error: 'User not found' });
    const status = Number(r.rows[0].status ?? 1);
    if (status === 1) return res.json({ ok: true, already_verified: true });

    const v = await client.query(
      `
      SELECT code, expires_at, used_at
      FROM email_verification_codes
      WHERE user_id = $1
        AND used_at IS NULL
      ORDER BY created_at DESC
      LIMIT 1
      `,
      [me],
    );
    if (v.rowCount === 0) return res.status(400).json({ error: 'Сначала запросите код' });
    const row = v.rows[0] as { code: string; expires_at: Date; used_at: Date | null };
    if (row.used_at) return res.status(400).json({ error: 'Код уже использован' });
    if (new Date(row.expires_at).getTime() < Date.now()) {
      return res.status(400).json({ error: 'Код истёк. Запросите новый' });
    }
    if (String(row.code) !== normalized) {
      return res.status(400).json({ error: 'Неверный код' });
    }

    await client.query('UPDATE users SET status = 1 WHERE id = $1', [me]);
    await client.query(
      `
      UPDATE email_verification_codes
      SET used_at = now()
      WHERE user_id = $1 AND used_at IS NULL
      `,
      [me],
    );
    return res.json({ ok: true });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.post('/change-email', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });

  const { email } = req.body as { email?: string };
  const normalizedEmail = typeof email === 'string' ? normalizeEmail(email) : '';
  if (!normalizedEmail || !isValidEmailFormat(normalizedEmail)) {
    return res.status(400).json({ error: 'Некорректный email' });
  }

  const client = await pool.connect();
  try {
    const existing = await client.query('SELECT 1 FROM users WHERE email = $1 AND id <> $2', [
      normalizedEmail,
      me,
    ]);
    if ((existing.rowCount ?? 0) > 0) {
      return res.status(409).json({ error: 'Этот email уже зарегистрирован' });
    }

    await client.query(`UPDATE users SET email = $1, status = 0 WHERE id = $2`, [
      normalizedEmail,
      me,
    ]);

    // Send fresh code to the new email.
    try {
      await createAndSendVerificationCode({ userId: me, email: normalizedEmail });
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn('Verification code send failed:', e);
    }

    const token = jwt.sign({ sub: me, email: normalizedEmail }, JWT_SECRET, {
      expiresIn: '7d',
    });
    return res.json({ ok: true, email: normalizedEmail, token });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.get('/verify-email', async (req, res) => {
  const token = typeof req.query.token === 'string' ? req.query.token.trim() : '';
  if (!token) return res.status(400).json({ error: 'token обязателен' });

  const client = await pool.connect();
  try {
    const r = await client.query(
      `
      SELECT token, user_id, expires_at, used_at
      FROM email_verifications
      WHERE token = $1
      `,
      [token],
    );
    if (r.rowCount === 0) return res.status(404).json({ error: 'Токен не найден' });
    const row = r.rows[0] as {
      user_id: string;
      expires_at: Date;
      used_at: Date | null;
    };
    if (row.used_at) return res.status(400).json({ error: 'Токен уже использован' });
    if (new Date(row.expires_at).getTime() < Date.now()) {
      return res.status(400).json({ error: 'Токен истёк' });
    }

    await client.query('UPDATE users SET status = 1 WHERE id = $1', [row.user_id]);
    await client.query('UPDATE email_verifications SET used_at = now() WHERE token = $1', [token]);
    return res.json({ ok: true });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.post('/resend-verification', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const r = await client.query('SELECT email, status FROM users WHERE id = $1', [me]);
    if (r.rowCount === 0) return res.status(404).json({ error: 'User not found' });
    const email = String(r.rows[0].email ?? '').trim();
    const status = Number(r.rows[0].status ?? 1);
    if (!email) return res.status(400).json({ error: 'Email not found' });
    if (status === 1) return res.json({ ok: true, already_verified: true });

    try {
      await createAndSendVerificationEmail({ userId: me, email });
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e);
      return res.status(500).json({ error: 'Не удалось отправить письмо' });
    }

    return res.json({ ok: true });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

export default router;

