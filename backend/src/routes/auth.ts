import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { pool } from '../db';

const router = Router();

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';

router.post('/register', async (req, res) => {
  const { email, password, username } = req.body as {
    email?: string;
    password?: string;
    username?: string;
  };
  if (!email || !password || password.length < 6) {
    return res.status(400).json({ error: 'Invalid email or password' });
  }
  const normalizedUsername =
    typeof username === 'string' ? username.trim() : undefined;
  if (normalizedUsername !== undefined) {
    if (normalizedUsername.length < 3 || normalizedUsername.length > 24) {
      return res.status(400).json({ error: 'Invalid username' });
    }
    if (!/^[a-zA-Z0-9_]+$/.test(normalizedUsername)) {
      return res.status(400).json({ error: 'Invalid username' });
    }
  }

  const client = await pool.connect();
  try {
    const existing = await client.query(
      'SELECT id FROM users WHERE email = $1',
      [email],
    );
    if (existing.rowCount && existing.rowCount > 0) {
      return res.status(409).json({ error: 'User already exists' });
    }
    if (normalizedUsername) {
      const existingUsername = await client.query(
        'SELECT 1 FROM users WHERE username = $1',
        [normalizedUsername],
      );
      if (existingUsername.rowCount && existingUsername.rowCount > 0) {
        return res.status(409).json({ error: 'Username already taken' });
      }
    }

    const hash = await bcrypt.hash(password, 10);
    const insert = await client.query(
      'INSERT INTO users (email, password_hash, username) VALUES ($1, $2, $3) RETURNING id, email, username, status, created_at',
      [email, hash, normalizedUsername ?? null],
    );

    const user = insert.rows[0];
    const token = jwt.sign({ sub: user.id, email: user.email }, JWT_SECRET, {
      expiresIn: '7d',
    });

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
      'SELECT id, email, username, status, password_hash FROM users WHERE email = $1',
      [email],
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

export default router;

