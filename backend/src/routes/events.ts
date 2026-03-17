import { Router } from 'express';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../middleware/auth';

const router = Router();

// Список событий в bbox (для карты)
router.get('/', async (req, res) => {
  const bbox = (req.query.bbox as string | undefined)?.split(',').map(Number);
  // bbox: minLon,minLat,maxLon,maxLat
  const client = await pool.connect();
  try {
    if (bbox && bbox.length === 4 && bbox.every((n) => Number.isFinite(n))) {
      const [minLon, minLat, maxLon, maxLat] = bbox;
      const result = await client.query(
        `
        SELECT id, title, description, lat, lon,
               marker_color_value, marker_icon_code, created_at, ends_at
        FROM events
        WHERE lon BETWEEN $1 AND $2
          AND lat BETWEEN $3 AND $4
          AND (ends_at IS NULL OR ends_at >= now())
        ORDER BY created_at DESC
        `,
        [minLon, maxLon, minLat, maxLat],
      );
      return res.json(result.rows);
    }

    const result = await client.query(
      `
      SELECT id, title, description, lat, lon,
             marker_color_value, marker_icon_code, created_at, ends_at
      FROM events
      WHERE (ends_at IS NULL OR ends_at >= now())
      ORDER BY created_at DESC
      LIMIT 200
      `,
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

// Комнаты, где я участвую (события с RSVP «приду»); чат остаётся и после окончания
router.get('/my/rooms', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  const client = await pool.connect();
  try {
    const result = await client.query(
      `
      SELECT e.id, e.title, e.description, e.lat, e.lon,
             e.marker_color_value, e.marker_icon_code, e.created_at, e.ends_at
      FROM events e
      INNER JOIN event_rsvp r ON r.event_id = e.id AND r.user_id = $1 AND r.status = 1
      ORDER BY e.ends_at ASC NULLS LAST, e.created_at DESC
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

// Детали события (с списками приду/не приду по email)
router.get('/:id', async (req, res) => {
  const { id } = req.params;
  const client = await pool.connect();
  try {
    const result = await client.query(
      `
      SELECT id, title, description, lat, lon,
             marker_color_value, marker_icon_code, created_at, ends_at
      FROM events
      WHERE id = $1
      `,
      [id],
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Event not found' });
    }
    const event = result.rows[0] as Record<string, unknown>;

    const going = await client.query(
      `
      SELECT u.id, u.email, u.username, u.display_name, u.avatar_url
      FROM event_rsvp r
      JOIN users u ON u.id = r.user_id
      WHERE r.event_id = $1 AND r.status = 1
      ORDER BY r.updated_at ASC
      `,
      [id],
    );
    const notGoing = await client.query(
      `
      SELECT u.id, u.email, u.username, u.display_name, u.avatar_url
      FROM event_rsvp r
      JOIN users u ON u.id = r.user_id
      WHERE r.event_id = $1 AND r.status = -1
      ORDER BY r.updated_at ASC
      `,
      [id],
    );

    (event as Record<string, unknown>).going_users = going.rows;
    (event as Record<string, unknown>).not_going_users = notGoing.rows;

    return res.json(event);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// RSVP: приду (1) / не приду (-1) / снять выбор (0 — удаляем запись)
router.post('/:id/rsvp', authMiddleware, async (req: AuthRequest, res) => {
  const { id: eventId } = req.params;
  const { status } = req.body as { status?: number };
  const userId = req.user?.id;
  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  if (status !== 1 && status !== -1 && status !== 0) {
    return res.status(400).json({ error: 'status must be 1 (приду), -1 (не приду) or 0 (снять)' });
  }

  const client = await pool.connect();
  try {
    if (status === 0) {
      await client.query(
        'DELETE FROM event_rsvp WHERE event_id = $1 AND user_id = $2',
        [eventId, userId],
      );
    } else {
      await client.query(
        `
        INSERT INTO event_rsvp (event_id, user_id, status)
        VALUES ($1, $2, $3)
        ON CONFLICT (event_id, user_id)
        DO UPDATE SET status = $3, updated_at = now()
        `,
        [eventId, userId, status],
      );
    }

    const going = await client.query(
      `SELECT u.id, u.email, u.username, u.display_name, u.avatar_url
       FROM event_rsvp r JOIN users u ON u.id = r.user_id
       WHERE r.event_id = $1 AND r.status = 1 ORDER BY r.updated_at ASC`,
      [eventId],
    );
    const notGoing = await client.query(
      `SELECT u.id, u.email, u.username, u.display_name, u.avatar_url
       FROM event_rsvp r JOIN users u ON u.id = r.user_id
       WHERE r.event_id = $1 AND r.status = -1 ORDER BY r.updated_at ASC`,
      [eventId],
    );

    return res.json({
      going_users: going.rows,
      not_going_users: notGoing.rows,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Сообщения по событию — только для участников (RSVP «приду»). После окончания события чат остаётся.
router.get('/:id/messages', authMiddleware, async (req: AuthRequest, res) => {
  const { id: eventId } = req.params;
  const userId = req.user?.id;
  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  const client = await pool.connect();
  try {
    const participant = await client.query(
      'SELECT 1 FROM event_rsvp WHERE event_id = $1 AND user_id = $2 AND status = 1',
      [eventId, userId],
    );
    if (participant.rowCount === 0) {
      return res.status(403).json({ error: 'Вы не участвуете в этом событии' });
    }
    const result = await client.query(
      `
      SELECT m.id,
             m.event_id,
             m.user_id,
             u.email AS user_email,
             m.text,
             m.created_at
      FROM event_messages m
      LEFT JOIN users u ON u.id = m.user_id
      WHERE m.event_id = $1
      ORDER BY m.created_at ASC
      `,
      [eventId],
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

// Отправить сообщение в чат события — только для участников (RSVP «приду»)
router.post('/:id/messages', authMiddleware, async (req: AuthRequest, res) => {
  const { id: eventId } = req.params;
  const userId = req.user?.id;
  const { text } = req.body as { text?: string };
  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  if (!text || typeof text !== 'string' || text.trim() === '') {
    return res.status(400).json({ error: 'Текст сообщения обязателен' });
  }
  const client = await pool.connect();
  try {
    const participant = await client.query(
      'SELECT 1 FROM event_rsvp WHERE event_id = $1 AND user_id = $2 AND status = 1',
      [eventId, userId],
    );
    if (participant.rowCount === 0) {
      return res.status(403).json({ error: 'Вы не участвуете в этом событии' });
    }
    const result = await client.query(
      `
      INSERT INTO event_messages (event_id, user_id, text)
      VALUES ($1, $2, $3)
      RETURNING id, event_id, user_id, text, created_at
      `,
      [eventId, userId, text.trim()],
    );
    const row = result.rows[0] as Record<string, unknown>;
    const userRow = await client.query('SELECT email FROM users WHERE id = $1', [userId]);
    (row as Record<string, unknown>).user_email = (userRow.rows[0] as { email: string })?.email ?? null;

    const socketIo = (req as unknown as { app: { get: (key: string) => unknown } }).app.get('io');
    if (socketIo && typeof (socketIo as { to: (room: string) => { emit: (ev: string, data: unknown) => void } }).to === 'function') {
      (socketIo as { to: (room: string) => { emit: (ev: string, data: unknown) => void } }).to(`event:${eventId}`).emit('newMessage', row);
    }

    return res.status(201).json(row);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Создание события (под JWT)
router.post('/', authMiddleware, async (req: AuthRequest, res) => {
  const {
    title,
    description,
    lat,
    lon,
    markerColorValue,
    markerIconCode,
    endsAt,
  } = req.body as {
    title?: string;
    description?: string;
    lat?: number;
    lon?: number;
    markerColorValue?: number;
    markerIconCode?: number;
    endsAt?: string;
  };

  // Логируем входящий payload для отладки
  // eslint-disable-next-line no-console
  console.log('POST /events body:', {
    title,
    description,
    lat,
    lon,
    markerColorValue,
    markerIconCode,
    endsAt,
    userId: req.user?.id,
  });

  if (
    !title ||
    typeof lat !== 'number' ||
    typeof lon !== 'number' ||
    typeof markerColorValue !== 'number' ||
    typeof markerIconCode !== 'number'
  ) {
    return res.status(400).json({ error: 'Invalid payload' });
  }

  if (!endsAt || typeof endsAt !== 'string' || endsAt.trim() === '') {
    return res.status(400).json({ error: 'Обязательно укажите дату окончания (endsAt)' });
  }

  const now = new Date();
  const maxEndsAt = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
  const endsAtDate = new Date(endsAt);
  if (Number.isNaN(endsAtDate.getTime())) {
    return res.status(400).json({ error: 'Invalid endsAt date' });
  }
  if (endsAtDate > maxEndsAt) {
    return res.status(400).json({ error: 'Дата окончания не более чем через неделю' });
  }
  if (endsAtDate < now) {
    return res.status(400).json({ error: 'Дата окончания не может быть в прошлом' });
  }

  const client = await pool.connect();
  try {
    const result = await client.query(
      `
      INSERT INTO events (title, description, lat, lon, marker_color_value, marker_icon_code, ends_at, created_by)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING id, title, description, lat, lon,
                marker_color_value, marker_icon_code, created_at, ends_at
      `,
      [
        title,
        description ?? '',
        lat,
        lon,
        markerColorValue,
        markerIconCode,
        endsAtDate,
        req.user?.id ?? null,
      ],
    );
    const created = result.rows[0];
    // eslint-disable-next-line no-console
    console.log('POST /events created:', created);
    return res.status(201).json(created);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Error in POST /events:', err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

export default router;

