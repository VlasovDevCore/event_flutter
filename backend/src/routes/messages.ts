import { Router } from 'express';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../middleware/auth';

const router = Router();

async function isBlockedEitherWay(
  client: { query: (q: string, p?: unknown[]) => Promise<{ rowCount: number | null }> },
  a: string,
  b: string,
) {
  const ab = await client.query(
    `SELECT 1 FROM user_blocks WHERE blocker_user_id = $1 AND blocked_user_id = $2`,
    [a, b],
  );
  const ba = await client.query(
    `SELECT 1 FROM user_blocks WHERE blocker_user_id = $1 AND blocked_user_id = $2`,
    [b, a],
  );
  return (ab.rowCount ?? 0) > 0 || (ba.rowCount ?? 0) > 0;
}

async function areFriends(
  client: { query: (q: string, p?: unknown[]) => Promise<{ rowCount: number | null }> },
  a: string,
  b: string,
) {
  const ab = await client.query(
    `SELECT 1 FROM friend_requests WHERE from_user_id = $1 AND to_user_id = $2 AND status = 'accepted'`,
    [a, b],
  );
  const ba = await client.query(
    `SELECT 1 FROM friend_requests WHERE from_user_id = $1 AND to_user_id = $2 AND status = 'accepted'`,
    [b, a],
  );
  return (ab.rowCount ?? 0) > 0 && (ba.rowCount ?? 0) > 0;
}

// Получить историю ЛС с пользователем
router.get('/with/:userId', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const other = req.params.userId as string;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!other) return res.status(400).json({ error: 'Invalid userId' });

  const client = await pool.connect();
  try {
    if (await isBlockedEitherWay(client, me, other)) {
      return res.status(403).json({ error: 'Чат недоступен: блокировка' });
    }
    const isFriends = await areFriends(client, me, other);
    const settings = await client.query(
      `SELECT allow_messages_from_non_friends FROM users WHERE id = $1`,
      [other],
    );
    if (settings.rowCount === 0) return res.status(404).json({ error: 'User not found' });
    const allowNonFriends = Boolean(settings.rows[0].allow_messages_from_non_friends);

    if (!isFriends && !allowNonFriends) {
      return res.status(403).json({ error: 'Пользователь не принимает сообщения от не друзей' });
    }

    const result = await client.query(
      `
      SELECT id, from_user_id, to_user_id, text, created_at
      FROM direct_messages
      WHERE (from_user_id = $1 AND to_user_id = $2)
         OR (from_user_id = $2 AND to_user_id = $1)
      ORDER BY created_at ASC
      LIMIT 200
      `,
      [me, other],
    );
    return res.json(result.rows);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Отправить сообщение пользователю
router.post('/with/:userId', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const other = req.params.userId as string;
  const { text } = req.body as { text?: string };
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!other) return res.status(400).json({ error: 'Invalid userId' });
  if (!text || typeof text !== 'string' || text.trim() === '') {
    return res.status(400).json({ error: 'Текст сообщения обязателен' });
  }
  if (other === me) return res.status(400).json({ error: 'Нельзя писать самому себе' });

  const client = await pool.connect();
  try {
    if (await isBlockedEitherWay(client, me, other)) {
      return res.status(403).json({ error: 'Нельзя отправить: блокировка' });
    }
    const isFriends = await areFriends(client, me, other);
    const settings = await client.query(
      `SELECT allow_messages_from_non_friends FROM users WHERE id = $1`,
      [other],
    );
    if (settings.rowCount === 0) return res.status(404).json({ error: 'User not found' });
    const allowNonFriends = Boolean(settings.rows[0].allow_messages_from_non_friends);

    if (!isFriends && !allowNonFriends) {
      return res.status(403).json({ error: 'Пользователь не принимает сообщения от не друзей' });
    }

    const insert = await client.query(
      `
      INSERT INTO direct_messages (from_user_id, to_user_id, text)
      VALUES ($1, $2, $3)
      RETURNING id, from_user_id, to_user_id, text, created_at
      `,
      [me, other, text.trim()],
    );
    return res.status(201).json(insert.rows[0]);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

export default router;

