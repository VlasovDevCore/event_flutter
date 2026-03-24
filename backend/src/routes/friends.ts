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

async function computeRelationship(
  client: { query: (q: string, p?: unknown[]) => Promise<{ rowCount: number | null }> },
  me: string,
  other: string,
) {
  const following = await client.query(
    `SELECT 1 FROM friend_requests WHERE from_user_id = $1 AND to_user_id = $2`,
    [me, other],
  );
  const followedBy = await client.query(
    `SELECT 1 FROM friend_requests WHERE from_user_id = $1 AND to_user_id = $2`,
    [other, me],
  );
  const meAccepted = await client.query(
    `SELECT 1 FROM friend_requests WHERE from_user_id = $1 AND to_user_id = $2 AND status = 'accepted'`,
    [me, other],
  );
  const otherAccepted = await client.query(
    `SELECT 1 FROM friend_requests WHERE from_user_id = $1 AND to_user_id = $2 AND status = 'accepted'`,
    [other, me],
  );
  return {
    isFollowing: (following.rowCount ?? 0) > 0,
    isFollowedBy: (followedBy.rowCount ?? 0) > 0,
    isFriends: (meAccepted.rowCount ?? 0) > 0 && (otherAccepted.rowCount ?? 0) > 0,
  };
}

// Статус отношений со мной (подписка/подписан/друзья)
router.get('/relationship/:userId', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const other = req.params.userId as string;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!other) return res.status(400).json({ error: 'Invalid userId' });
  if (other === me) return res.json({ isFollowing: false, isFollowedBy: false, isFriends: false });

  const client = await pool.connect();
  try {
    const u = await client.query('SELECT 1 FROM users WHERE id = $1', [other]);
    if (u.rowCount === 0) return res.status(404).json({ error: 'Пользователь не найден' });

    const rel = await computeRelationship(client, me, other);
    return res.json(rel);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Подписаться (если взаимно — автоматически друзья)
router.post('/subscribe', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const { toUserId } = req.body as { toUserId?: string };
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!toUserId || typeof toUserId !== 'string') return res.status(400).json({ error: 'Укажите toUserId' });
  if (toUserId === me) return res.status(400).json({ error: 'Нельзя подписаться на себя' });

  const client = await pool.connect();
  try {
    const userCheck = await client.query('SELECT 1 FROM users WHERE id = $1', [toUserId]);
    if (userCheck.rowCount === 0) return res.status(404).json({ error: 'Пользователь не найден' });

    if (await isBlockedEitherWay(client, me, toUserId)) {
      return res.status(403).json({ error: 'Нельзя подписаться: блокировка' });
    }

    await client.query(
      `
      INSERT INTO friend_requests (from_user_id, to_user_id, status)
      VALUES ($1, $2, 'pending')
      ON CONFLICT (from_user_id, to_user_id) DO NOTHING
      `,
      [me, toUserId],
    );

    const opposite = await client.query(
      `SELECT status FROM friend_requests WHERE from_user_id = $1 AND to_user_id = $2`,
      [toUserId, me],
    );
    if ((opposite.rowCount ?? 0) > 0) {
      // Взаимная подписка => друзья: accepted в обе стороны (создадим/обновим оба ребра)
      await client.query(
        `
        INSERT INTO friend_requests (from_user_id, to_user_id, status)
        VALUES ($1, $2, 'accepted')
        ON CONFLICT (from_user_id, to_user_id) DO UPDATE SET status = 'accepted'
        `,
        [me, toUserId],
      );
      await client.query(
        `
        INSERT INTO friend_requests (from_user_id, to_user_id, status)
        VALUES ($1, $2, 'accepted')
        ON CONFLICT (from_user_id, to_user_id) DO UPDATE SET status = 'accepted'
        `,
        [toUserId, me],
      );
    }

    const rel = await computeRelationship(client, me, toUserId);
    return res.status(201).json(rel);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Отписаться (если были друзья — дружба снимается, у второго останется pending если он всё ещё подписан)
router.post('/unsubscribe', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const { toUserId } = req.body as { toUserId?: string };
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!toUserId || typeof toUserId !== 'string') return res.status(400).json({ error: 'Укажите toUserId' });
  if (toUserId === me) return res.status(400).json({ error: 'Нельзя отписаться от себя' });

  const client = await pool.connect();
  try {
    if (await isBlockedEitherWay(client, me, toUserId)) {
      // unblock required before any relationship actions
      return res.status(403).json({ error: 'Действие недоступно: блокировка' });
    }
    // удаляем моё ребро
    await client.query(
      `DELETE FROM friend_requests WHERE from_user_id = $1 AND to_user_id = $2`,
      [me, toUserId],
    );
    // если у второго было accepted -> опускаем до pending (он подписан, но уже не друзья)
    await client.query(
      `
      UPDATE friend_requests
      SET status = 'pending'
      WHERE from_user_id = $1 AND to_user_id = $2 AND status = 'accepted'
      `,
      [toUserId, me],
    );

    const rel = await computeRelationship(client, me, toUserId);
    return res.json(rel);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Входящие заявки в друзья (кто меня добавил, ожидают ответа)
router.get('/requests', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const result = await client.query(
      `
      SELECT 
        fr.id, 
        fr.from_user_id, 
        fr.to_user_id, 
        fr.status, 
        fr.created_at,
        u.email AS from_email,
        u.username,
        u.display_name,
        u.avatar_url
      FROM friend_requests fr
      JOIN users u ON u.id = fr.from_user_id
      WHERE fr.to_user_id = $1 AND fr.status = 'pending'
      ORDER BY fr.created_at DESC
      `,
      [userId],
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

// Отправить заявку в друзья
router.post('/requests', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  const { toUserId } = req.body as { toUserId?: string };
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });
  if (!toUserId || typeof toUserId !== 'string') {
    return res.status(400).json({ error: 'Укажите toUserId' });
  }
  if (toUserId === userId) {
    return res.status(400).json({ error: 'Нельзя отправить заявку себе' });
  }

  const client = await pool.connect();
  try {
    const userCheck = await client.query('SELECT 1 FROM users WHERE id = $1', [toUserId]);
    if (userCheck.rowCount === 0) {
      return res.status(404).json({ error: 'Пользователь не найден' });
    }

    await client.query(
      `
      INSERT INTO friend_requests (from_user_id, to_user_id, status)
      VALUES ($1, $2, 'pending')
      ON CONFLICT (from_user_id, to_user_id) DO NOTHING
      `,
      [userId, toUserId],
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

// Принять заявку
router.post('/requests/:id/accept', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const result = await client.query(
      `UPDATE friend_requests SET status = 'accepted'
       WHERE id = $1 AND to_user_id = $2 AND status = 'pending'
       RETURNING id`,
      [id, userId],
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Заявка не найдена или уже обработана' });
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

// Отклонить заявку
router.post('/requests/:id/reject', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  const { id } = req.params;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    await client.query(
      `DELETE FROM friend_requests
       WHERE id = $1 AND to_user_id = $2 AND status = 'pending'`,
      [id, userId],
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

// Список моих друзей (принятые заявки в обе стороны)
router.get('/', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    // Друзья = взаимная подписка (accepted в обе стороны).
    // Важно: после auto-friends у нас 2 ребра (A->B, B->A), поэтому делаем DISTINCT по пользователю.
    const result = await client.query(
      `
      SELECT DISTINCT ON (u.id)
        u.id,
        u.email,
        COALESCE(u.username, '') AS username,
        COALESCE(u.display_name, '') AS display_name,
        u.avatar_url,
        GREATEST(fr1.created_at, fr2.created_at) AS friends_since
      FROM users u
      JOIN friend_requests fr1
        ON fr1.from_user_id = $1 AND fr1.to_user_id = u.id AND fr1.status = 'accepted'
      JOIN friend_requests fr2
        ON fr2.from_user_id = u.id AND fr2.to_user_id = $1 AND fr2.status = 'accepted'
      WHERE u.id <> $1
      ORDER BY u.id, friends_since DESC
      `,
      [userId],
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

// Список пользователей для поиска друзей
router.get('/users', authMiddleware, async (req: AuthRequest, res) => {
  const currentUserId = req.user?.id;
  if (!currentUserId) return res.status(401).json({ error: 'Unauthorized' });

  const { search = '' } = req.query;
  const searchTerm = (search as string).trim();

  const client = await pool.connect();
  try {
    let query = `
      SELECT 
        id,
        email,
        username,
        display_name,
        avatar_url,
        created_at
      FROM users
      WHERE id != $1
    `;
    
    const params: unknown[] = [currentUserId];
    
    // Если есть поиск — ищем по всем пользователям
    if (searchTerm) {
      query += `
        AND (
          email ILIKE $2 OR 
          username ILIKE $2 OR 
          display_name ILIKE $2
        )
        ORDER BY 
          CASE 
            WHEN username ILIKE $2 THEN 1
            WHEN display_name ILIKE $2 THEN 2
            ELSE 3
          END,
          display_name NULLS LAST, 
          username NULLS LAST
      `;
      params.push(`%${searchTerm}%`);
    } else {
      // Если нет поиска — рандомные 20 пользователей
      query += ` ORDER BY RANDOM() LIMIT 20`;
    }
    
    const result = await client.query(query, params);
    return res.json(result.rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.get('/requests/sent', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const result = await client.query(
      `
      SELECT 
        fr.id, 
        fr.from_user_id, 
        fr.to_user_id, 
        fr.status, 
        fr.created_at,
        u.email AS to_email,
        u.username,
        u.display_name,
        u.avatar_url
      FROM friend_requests fr
      JOIN users u ON u.id = fr.to_user_id
      WHERE fr.from_user_id = $1 AND fr.status = 'pending'
      ORDER BY fr.created_at DESC
      `,
      [userId],
    );
    return res.json(result.rows);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.get('/requests/:toUserId', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  const { toUserId } = req.params;
  
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });
  if (!toUserId) return res.status(400).json({ error: 'Укажите toUserId' });

  const client = await pool.connect();
  try {
    // Удаляем только если заявка от текущего пользователя и статус pending
    const result = await client.query(
      `DELETE FROM friend_requests 
       WHERE from_user_id = $1 AND to_user_id = $2 AND status = 'pending'
       RETURNING id`,
      [userId, toUserId],
    );
    
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Заявка не найдена' });
    }
    
    return res.json({ ok: true });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

export default router;
