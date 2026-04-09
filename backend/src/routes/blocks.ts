import { Router } from 'express';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../middleware/auth';

const router = Router();

// Список пользователей, с кем есть блокировка в любую сторону.
router.get('/list', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const r = await client.query(
      `
      SELECT DISTINCT peer_id FROM (
        SELECT blocked_user_id AS peer_id
        FROM user_blocks
        WHERE blocker_user_id = $1
        UNION ALL
        SELECT blocker_user_id AS peer_id
        FROM user_blocks
        WHERE blocked_user_id = $1
      ) t
      `,
      [me],
    );
    const userIds = r.rows.map((row) => String(row.peer_id));
    return res.json({ userIds });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.get('/status/:userId', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const other = req.params.userId as string;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!other) return res.status(400).json({ error: 'Invalid userId' });
  if (other === me) return res.json({ isBlocked: false, isBlockedBy: false });

  const client = await pool.connect();
  try {
    const isBlocked = await client.query(
      `SELECT 1 FROM user_blocks WHERE blocker_user_id = $1 AND blocked_user_id = $2`,
      [me, other],
    );
    const isBlockedBy = await client.query(
      `SELECT 1 FROM user_blocks WHERE blocker_user_id = $1 AND blocked_user_id = $2`,
      [other, me],
    );
    return res.json({
      isBlocked: (isBlocked.rowCount ?? 0) > 0,
      isBlockedBy: (isBlockedBy.rowCount ?? 0) > 0,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.post('/block', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const { userId } = req.body as { userId?: string };
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!userId || typeof userId !== 'string') return res.status(400).json({ error: 'Укажите userId' });
  if (userId === me) return res.status(400).json({ error: 'Нельзя заблокировать себя' });

  const client = await pool.connect();
  try {
    const u = await client.query('SELECT 1 FROM users WHERE id = $1', [userId]);
    if (u.rowCount === 0) return res.status(404).json({ error: 'Пользователь не найден' });

    await client.query(
      `
      INSERT INTO user_blocks (blocker_user_id, blocked_user_id)
      VALUES ($1, $2)
      ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING
      `,
      [me, userId],
    );

    // optional: remove follow edges both ways when blocking
    await client.query(
      `DELETE FROM friend_requests WHERE (from_user_id = $1 AND to_user_id = $2) OR (from_user_id = $2 AND to_user_id = $1)`,
      [me, userId],
    );

    return res.status(201).json({ ok: true });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.post('/unblock', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const { userId } = req.body as { userId?: string };
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!userId || typeof userId !== 'string') return res.status(400).json({ error: 'Укажите userId' });

  const client = await pool.connect();
  try {
    await client.query(
      `DELETE FROM user_blocks WHERE blocker_user_id = $1 AND blocked_user_id = $2`,
      [me, userId],
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

export default router;

