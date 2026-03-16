import { Router } from 'express';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../middleware/auth';

const router = Router();

// Входящие заявки в друзья (кто меня добавил, ожидают ответа)
router.get('/requests', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const result = await client.query(
      `
      SELECT fr.id, fr.from_user_id, fr.to_user_id, fr.status, fr.created_at,
             u.email AS from_email
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
    const result = await client.query(
      `
      SELECT u.id, u.email, fr.created_at AS friends_since
      FROM friend_requests fr
      JOIN users u ON u.id = CASE WHEN fr.from_user_id = $1 THEN fr.to_user_id ELSE fr.from_user_id END
      WHERE (fr.from_user_id = $1 OR fr.to_user_id = $1) AND fr.status = 'accepted'
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

export default router;
