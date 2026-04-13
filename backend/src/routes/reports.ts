import { Router } from 'express';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../middleware/auth';

const router = Router();

router.post('/user', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });

  const { userId, category, message } = req.body as {
    userId?: string;
    category?: string;
    message?: string;
  };

  const reportedUserId = typeof userId === 'string' ? userId.trim() : '';
  const normalizedCategory = typeof category === 'string' ? category.trim() : '';
  const normalizedMessage = typeof message === 'string' ? message.trim() : '';

  if (!reportedUserId) return res.status(400).json({ error: 'Укажите userId' });
  if (reportedUserId === me) return res.status(400).json({ error: 'Нельзя пожаловаться на себя' });
  if (!normalizedCategory) return res.status(400).json({ error: 'Укажите category' });
  if (!normalizedMessage || normalizedMessage.length < 10) {
    return res.status(400).json({ error: 'Описание должно быть минимум 10 символов' });
  }
  if (normalizedMessage.length > 2000) {
    return res.status(400).json({ error: 'Описание слишком длинное' });
  }
  if (normalizedCategory.length > 80) {
    return res.status(400).json({ error: 'Некорректная category' });
  }

  const client = await pool.connect();
  try {
    const u = await client.query('SELECT 1 FROM users WHERE id = $1', [reportedUserId]);
    if (u.rowCount === 0) return res.status(404).json({ error: 'Пользователь не найден' });

    const ins = await client.query(
      `
      INSERT INTO user_reports (reporter_user_id, reported_user_id, category, message)
      VALUES ($1, $2, $3, $4)
      RETURNING id
      `,
      [me, reportedUserId, normalizedCategory, normalizedMessage],
    );
    return res.status(201).json({ ok: true, reportId: ins.rows[0]?.id });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.post('/event', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });

  const { eventId, category, message } = req.body as {
    eventId?: string;
    category?: string;
    message?: string;
  };

  const normalizedEventId = typeof eventId === 'string' ? eventId.trim() : '';
  const normalizedCategory = typeof category === 'string' ? category.trim() : '';
  const normalizedMessage = typeof message === 'string' ? message.trim() : '';

  if (!normalizedEventId) return res.status(400).json({ error: 'Укажите eventId' });
  if (!normalizedCategory) return res.status(400).json({ error: 'Укажите category' });
  if (!normalizedMessage || normalizedMessage.length < 10) {
    return res.status(400).json({ error: 'Описание должно быть минимум 10 символов' });
  }
  if (normalizedMessage.length > 2000) {
    return res.status(400).json({ error: 'Описание слишком длинное' });
  }
  if (normalizedCategory.length > 80) {
    return res.status(400).json({ error: 'Некорректная category' });
  }

  const client = await pool.connect();
  try {
    const e = await client.query('SELECT 1 FROM events WHERE id = $1', [normalizedEventId]);
    if (e.rowCount === 0) return res.status(404).json({ error: 'Событие не найдено' });

    const ins = await client.query(
      `
      INSERT INTO event_reports (reporter_user_id, event_id, category, message)
      VALUES ($1, $2, $3, $4)
      RETURNING id
      `,
      [me, normalizedEventId, normalizedCategory, normalizedMessage],
    );
    return res.status(201).json({ ok: true, reportId: ins.rows[0]?.id });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

export default router;

