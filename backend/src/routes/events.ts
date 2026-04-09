import { Router } from 'express';
import type { PoolClient } from 'pg';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { pool } from '../db';
import { authMiddleware, AuthRequest, optionalAuthMiddleware } from '../middleware/auth';
import { notifyEventChatMessage } from '../services/push';
import { decryptMessageText, encryptMessageText } from '../utils/messageCrypto';

const router = Router();

type RoomsMetaMap = Record<
  string,
  {
    unread_count: number;
    muted_until: string | null;
  }
>;

/** Те же going_users / not_going_users, что у GET /events/:id — для списков «мои комнаты» / «создал». */
async function attachRsvpListsToEventRows(
  client: PoolClient,
  rows: Record<string, unknown>[],
): Promise<void> {
  if (rows.length === 0) return;
  const ids = rows.map((r) => r.id as string);

  const going = await client.query(
    `
    SELECT r.event_id, u.id, u.email, u.username, u.display_name, u.avatar_url, u.status
    FROM event_rsvp r
    JOIN users u ON u.id = r.user_id
    WHERE r.event_id = ANY($1::uuid[]) AND r.status = 1
    ORDER BY r.event_id, r.updated_at DESC
    `,
    [ids],
  );
  const notGoing = await client.query(
    `
    SELECT r.event_id, u.id, u.email, u.username, u.display_name, u.avatar_url, u.status
    FROM event_rsvp r
    JOIN users u ON u.id = r.user_id
    WHERE r.event_id = ANY($1::uuid[]) AND r.status = -1
    ORDER BY r.event_id, r.updated_at ASC
    `,
    [ids],
  );

  const mapGoing = new Map<string, Record<string, unknown>[]>();
  for (const row of going.rows) {
    const eid = row.event_id as string;
    const { event_id: _e, ...user } = row;
    if (!mapGoing.has(eid)) mapGoing.set(eid, []);
    mapGoing.get(eid)!.push(user as Record<string, unknown>);
  }
  const mapNotGoing = new Map<string, Record<string, unknown>[]>();
  for (const row of notGoing.rows) {
    const eid = row.event_id as string;
    const { event_id: _e, ...user } = row;
    if (!mapNotGoing.has(eid)) mapNotGoing.set(eid, []);
    mapNotGoing.get(eid)!.push(user as Record<string, unknown>);
  }

  for (const row of rows) {
    const id = row.id as string;
    row.going_users = mapGoing.get(id) ?? [];
    row.not_going_users = mapNotGoing.get(id) ?? [];
  }
}

// Тип для новости
interface NewsItem {
  id: string;
  title: string;
  description: string;
  image_url: string | null;
  created_at: Date;
  view_count: number;
  is_viewed: boolean;
}

const uploadsDir = path.join(process.cwd(), 'uploads');
const eventImagesBaseDir = path.join(uploadsDir, 'events');
try {
  fs.mkdirSync(eventImagesBaseDir, { recursive: true });
} catch {
  // ignore
}

function todayFolderName() {
  // YYYY-MM-DD (UTC), чтобы имя папки было консистентным
  return new Date().toISOString().slice(0, 10);
}

const uploadEventImage = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => {
      const dayDir = path.join(eventImagesBaseDir, todayFolderName());
      try {
        fs.mkdirSync(dayDir, { recursive: true });
      } catch {
        // ignore
      }
      cb(null, dayDir);
    },
    filename: (req, file, cb) => {
      const eventId = (req.params as any).id ?? 'event';
      const ext = path.extname(file.originalname || '') || '.jpg';
      const safeExt = ext.length <= 8 ? ext : '.jpg';
      cb(null, `${eventId}-${Date.now()}${safeExt}`);
    },
  }),
  limits: {
    fileSize: 8 * 1024 * 1024, // 8MB
  },
  fileFilter: (_req, file, cb) => {
    const mimetype = file.mimetype ?? '';
    const ext = path.extname(file.originalname || '').toLowerCase();
    const okByMime = mimetype.startsWith('image/');
    const okByExt = ['.jpg', '.jpeg', '.png', '.gif', '.webp'].includes(ext);
    if (!okByMime && !okByExt) {
      return cb(new Error('Only image uploads are allowed'));
    }
    cb(null, true);
  },
});

function resolveUploadsFilePathFromUrl(imageUrl: string): string | null {
  const u = imageUrl.trim();
  if (!u.startsWith('/uploads/')) return null;
  // avoid path traversal: resolve and ensure within uploadsDir
  const rel = u.replace('/uploads/', '');
  const abs = path.resolve(uploadsDir, rel);
  const uploadsAbs = path.resolve(uploadsDir);
  if (!abs.startsWith(uploadsAbs)) return null;
  return abs;
}

async function tryDeleteOldEventImage(client: PoolClient, eventId: string): Promise<void> {
  const r = await client.query(`SELECT image_url FROM events WHERE id = $1`, [eventId]);
  const old = (r.rows[0]?.image_url as string | null | undefined) ?? null;
  if (!old) return;
  // only delete our uploads files
  const abs = resolveUploadsFilePathFromUrl(old);
  if (!abs) return;
  try {
    await fs.promises.unlink(abs);
  } catch {
    // ignore (already deleted or inaccessible)
  }
}

// Получить список новостей с отметкой о просмотре
router.get('/news', authMiddleware, async (req: AuthRequest, res) => {
  const client = await pool.connect();
  try {
    const userId = req.user?.id;
    
    const result = await client.query(
      `
      SELECT 
        n.id, 
        n.title, 
        n.description, 
        n.image_url, 
        n.created_at,
        COUNT(v.user_id) as view_count,
        CASE WHEN v2.user_id IS NOT NULL THEN true ELSE false END as is_viewed
      FROM news n
      LEFT JOIN viewed_news v ON v.news_id = n.id
      LEFT JOIN viewed_news v2 ON v2.news_id = n.id AND v2.user_id = $1
      WHERE n.is_published = true
      GROUP BY n.id, v2.user_id
      ORDER BY n.created_at DESC
      LIMIT 50
      `,
      [userId || null]
    );
    
    const newsMap: Record<string, any> = {};
    result.rows.forEach((news) => {
      newsMap[news.id] = {
        id: news.id,
        title: news.title,
        description: news.description,
        image_url: news.image_url,
        created_at: news.created_at,
        view_count: parseInt(news.view_count),
        is_viewed: news.is_viewed
      };
    });
    
    return res.json(newsMap);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Есть ли непрочитанные новости (для индикатора "точка" в UI).
router.get('/news/unread-flag', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const r = await client.query(
      `
      SELECT 1
      FROM news n
      WHERE n.is_published = true
        AND NOT EXISTS (
          SELECT 1 FROM viewed_news v
          WHERE v.news_id = n.id AND v.user_id = $1
        )
      LIMIT 1
      `,
      [userId],
    );
    return res.json({ has_unread: (r.rowCount ?? 0) > 0 });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Загрузить фотографию события (multipart/form-data, field name: image).
// Только создатель события.
router.post(
  '/:id/image',
  authMiddleware,
  uploadEventImage.single('image'),
  async (req: AuthRequest, res) => {
    const eventId = String(req.params.id);
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });
    if (!eventId) return res.status(400).json({ error: 'Invalid event id' });
    if (!req.file) return res.status(400).json({ error: 'image is required' });

    const client = await pool.connect();
    try {
      const ownership = await client.query(
        `SELECT created_by FROM events WHERE id = $1`,
        [eventId],
      );
      if (ownership.rowCount === 0) {
        return res.status(404).json({ error: 'Event not found' });
      }
      const ownerId = (ownership.rows[0] as { created_by: string | null }).created_by;
      if (!ownerId || ownerId !== userId) {
        return res.status(403).json({ error: 'Только создатель может менять фото события' });
      }

      await tryDeleteOldEventImage(client, eventId);

      // req.file.destination — реальный путь на диске; конвертим в URL-формат.
      const fileDestination = (req.file as any).destination as string | undefined;
      const relToUploads =
        fileDestination != null ? path.relative(uploadsDir, fileDestination) : null;
      const relToUploadsUrl =
        relToUploads != null ? relToUploads.split(path.sep).join('/') : 'events';
      const relativeUrl = `/uploads/${relToUploadsUrl}/${req.file.filename}`;

      await client.query(`UPDATE events SET image_url = $1 WHERE id = $2`, [
        relativeUrl,
        eventId,
      ]);
      return res.json({ success: true, image_url: relativeUrl });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(err);
      return res.status(500).json({ error: 'Internal error' });
    } finally {
      client.release();
    }
  },
);

// Удалить фотографию события (и файл), только создатель события.
router.delete('/:id/image', authMiddleware, async (req: AuthRequest, res) => {
  const eventId = String(req.params.id);
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });
  if (!eventId) return res.status(400).json({ error: 'Invalid event id' });

  const client = await pool.connect();
  try {
    const ownership = await client.query(`SELECT created_by FROM events WHERE id = $1`, [eventId]);
    if (ownership.rowCount === 0) return res.status(404).json({ error: 'Event not found' });
    const ownerId = (ownership.rows[0] as { created_by: string | null }).created_by;
    if (!ownerId || ownerId !== userId) {
      return res.status(403).json({ error: 'Только создатель может менять фото события' });
    }

    await tryDeleteOldEventImage(client, eventId);
    await client.query(`UPDATE events SET image_url = NULL WHERE id = $1`, [eventId]);
    return res.json({ success: true, image_url: null });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Получить детальную новость по ID
router.get('/news/:id', authMiddleware, async (req: AuthRequest, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const client = await pool.connect();
  
  try {
    // Получаем новость с количеством просмотров
    const result = await client.query(
      `
      SELECT 
        n.id, 
        n.title, 
        n.description, 
        n.image_url, 
        n.created_at,
        COUNT(v.user_id) as view_count,
        u.display_name as author_name,
        u.email as author_email
      FROM news n
      LEFT JOIN viewed_news v ON v.news_id = n.id
      LEFT JOIN users u ON u.id = n.created_by
      WHERE n.id = $1 AND n.is_published = true
      GROUP BY n.id, u.display_name, u.email
      `,
      [id]
    );
    
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'News not found' });
    }
    
    // Отмечаем просмотр текущим пользователем
    if (userId) {
      await client.query(
        `INSERT INTO viewed_news (user_id, news_id) 
         VALUES ($1, $2) 
         ON CONFLICT (user_id, news_id) DO NOTHING`,
        [userId, id]
      );
    }
    
    const news = result.rows[0];
    news.view_count = parseInt(news.view_count);
    
    return res.json(news);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// В маршруте POST /news/:id/view
router.post('/news/:id/view', authMiddleware, async (req: AuthRequest, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  
  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  const client = await pool.connect();
  try {
    // Добавляем запись о просмотре
    await client.query(
      `INSERT INTO viewed_news (user_id, news_id) 
       VALUES ($1, $2) 
       ON CONFLICT (user_id, news_id) DO NOTHING`,
      [userId, id]
    );
    
    // Получаем общее количество просмотров
    const countResult = await client.query(
      'SELECT COUNT(*) as total FROM viewed_news WHERE news_id = $1',
      [id]
    );
    
    const totalViews = parseInt(countResult.rows[0].total);
    
    return res.json({ 
      success: true,
      view_count: totalViews
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Список событий в bbox (для карты)
router.get('/', optionalAuthMiddleware, async (req: AuthRequest, res) => {
  const bbox = (req.query.bbox as string | undefined)?.split(',').map(Number);
  // bbox: minLon,minLat,maxLon,maxLat
  const me = req.user?.id;
  const client = await pool.connect();
  try {
    if (bbox && bbox.length === 4 && bbox.every((n) => Number.isFinite(n))) {
      const [minLon, minLat, maxLon, maxLat] = bbox;
      const result = await client.query(
        `
        SELECT e.id, e.title, e.description, e.image_url, e.lat, e.lon,
               e.marker_color_value, e.marker_icon_code, e.created_at, e.ends_at,
               e.created_by AS created_by_user_id,
               u.email AS created_by_email,
               u.username AS created_by_username,
               u.display_name AS created_by_display_name
        FROM events e
        LEFT JOIN users u ON u.id = e.created_by
        WHERE lon BETWEEN $1 AND $2
          AND lat BETWEEN $3 AND $4
          AND (ends_at IS NULL OR ends_at >= now())
          AND (
            $5::uuid IS NULL
            OR NOT EXISTS (
              SELECT 1 FROM event_blacklist bl
              WHERE bl.event_id = e.id AND bl.user_id = $5
            )
          )
        ORDER BY e.created_at DESC
        `,
        [minLon, maxLon, minLat, maxLat, me ?? null],
      );
      return res.json(result.rows);
    }

    const result = await client.query(
      `
      SELECT e.id, e.title, e.description, e.image_url, e.lat, e.lon,
             e.marker_color_value, e.marker_icon_code, e.created_at, e.ends_at,
             e.created_by AS created_by_user_id,
             u.email AS created_by_email,
             u.username AS created_by_username,
             u.display_name AS created_by_display_name
      FROM events e
      LEFT JOIN users u ON u.id = e.created_by
      WHERE (e.ends_at IS NULL OR e.ends_at >= now())
        AND (
          $1::uuid IS NULL
          OR NOT EXISTS (
            SELECT 1 FROM event_blacklist bl
            WHERE bl.event_id = e.id AND bl.user_id = $1
          )
        )
      ORDER BY e.created_at DESC
      LIMIT 200
      `,
      [me ?? null],
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
      SELECT e.id, e.title, e.description, e.image_url, e.lat, e.lon,
             e.marker_color_value, e.marker_icon_code, e.created_at, e.ends_at,
             e.created_by AS created_by_user_id,
             u.email AS created_by_email,
             u.username AS created_by_username,
             u.display_name AS created_by_display_name
      FROM events e
      LEFT JOIN users u ON u.id = e.created_by
      INNER JOIN event_rsvp r ON r.event_id = e.id AND r.user_id = $1 AND r.status = 1
      ORDER BY e.ends_at ASC NULLS LAST, e.created_at DESC
      `,
      [userId],
    );
    const rows = result.rows as Record<string, unknown>[];
    await attachRsvpListsToEventRows(client, rows);
    return res.json(rows);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Общее количество непрочитанных сообщений в чатах событий (по моим комнатам RSVP=1).
router.get('/unread-count', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const r = await client.query(
      `
      SELECT COUNT(*)::int AS count
      FROM event_messages m
      JOIN event_rsvp rsvp
        ON rsvp.event_id = m.event_id
       AND rsvp.user_id = $1
       AND rsvp.status = 1
      WHERE m.user_id <> $1
        AND NOT EXISTS (
          SELECT 1 FROM event_message_views v
          WHERE v.message_id = m.id AND v.user_id = $1
        )
      `,
      [userId],
    );
    const count = (r.rows[0]?.count as number) ?? 0;
    return res.json({ count });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Мета по комнатам (unread + mute) для списка «мои комнаты».
// Body: { eventIds: string[] }
router.post('/rooms-meta', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  const { eventIds } = (req.body ?? {}) as { eventIds?: unknown };
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });
  if (!Array.isArray(eventIds)) {
    return res.status(400).json({ error: 'eventIds обязателен (array)' });
  }
  const ids = eventIds
    .map((x) => (typeof x === 'string' ? x.trim() : ''))
    .filter((x) => x !== '');
  if (ids.length === 0) return res.json({ byEvent: {} satisfies RoomsMetaMap });

  const client = await pool.connect();
  try {
    // unread_count: чужие сообщения без отметки просмотра текущим пользователем
    const unreadR = await client.query(
      `
      SELECT m.event_id, COUNT(*)::int AS cnt
      FROM event_messages m
      WHERE m.event_id = ANY($1::uuid[])
        AND m.user_id <> $2
        AND NOT EXISTS (
          SELECT 1 FROM event_message_views v
          WHERE v.message_id = m.id AND v.user_id = $2
        )
      GROUP BY m.event_id
      `,
      [ids, userId],
    );

    const muteR = await client.query(
      `
      SELECT event_id, muted_until
      FROM user_event_chat_mutes
      WHERE user_id = $1 AND event_id = ANY($2::uuid[])
      `,
      [userId, ids],
    );

    const byEvent: RoomsMetaMap = {};
    for (const id of ids) {
      byEvent[id] = { unread_count: 0, muted_until: null };
    }

    for (const row of unreadR.rows) {
      const eid = row.event_id as string;
      const cnt = row.cnt as number;
      if (!byEvent[eid]) byEvent[eid] = { unread_count: 0, muted_until: null };
      byEvent[eid].unread_count = cnt;
    }

    for (const row of muteR.rows) {
      const eid = row.event_id as string;
      const until = (row.muted_until as Date | null) ?? null;
      if (!byEvent[eid]) byEvent[eid] = { unread_count: 0, muted_until: null };
      byEvent[eid].muted_until = until ? until.toISOString() : null;
    }

    return res.json({ byEvent });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// События, которые создал текущий пользователь (включая завершённые)
router.get('/my/created', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  const client = await pool.connect();
  try {
    const result = await client.query(
      `
      SELECT e.id, e.title, e.description, e.image_url, e.lat, e.lon,
             e.marker_color_value, e.marker_icon_code, e.created_at, e.ends_at,
             e.created_by AS created_by_user_id,
             u.email AS created_by_email,
             u.username AS created_by_username,
             u.display_name AS created_by_display_name
      FROM events e
      LEFT JOIN users u ON u.id = e.created_by
      WHERE e.created_by = $1
      ORDER BY e.ends_at ASC NULLS LAST, e.created_at DESC
      `,
      [userId],
    );
    const rows = result.rows as Record<string, unknown>[];
    await attachRsvpListsToEventRows(client, rows);
    return res.json(rows);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Детали события (с списками приду/не приду по email)
router.get('/:id', optionalAuthMiddleware, async (req: AuthRequest, res) => {
  const { id } = req.params;
  const client = await pool.connect();
  try {
    const me = req.user?.id;
    if (me) {
      const bl = await client.query(
        `SELECT 1 FROM event_blacklist WHERE event_id = $1 AND user_id = $2`,
        [id, me],
      );
      if ((bl.rowCount ?? 0) > 0) {
        return res.status(404).json({ error: 'Event not found' });
      }
    }

    const result = await client.query(
      `
      SELECT e.id, e.title, e.description, e.image_url, e.lat, e.lon,
             e.marker_color_value, e.marker_icon_code, e.created_at, e.ends_at,
             e.created_by AS created_by_user_id,
             u.email AS created_by_email,
             u.username AS created_by_username,
             u.display_name AS created_by_display_name
      FROM events e
      LEFT JOIN users u ON u.id = e.created_by
      WHERE e.id = $1
      `,
      [id],
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Event not found' });
    }
    const event = result.rows[0] as Record<string, unknown>;

    const going = await client.query(
      `
      SELECT u.id, u.email, u.username, u.display_name, u.avatar_url, u.status
      FROM event_rsvp r
      JOIN users u ON u.id = r.user_id
      WHERE r.event_id = $1 AND r.status = 1
      ORDER BY r.updated_at DESC
      `,
      [id],
    );
    const notGoing = await client.query(
      `
      SELECT u.id, u.email, u.username, u.display_name, u.avatar_url, u.status
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

// Черный список события (только создатель события)
router.get('/:id/blacklist/count', authMiddleware, async (req: AuthRequest, res) => {
  const eventId = String(req.params.id);
  const me = req.user?.id;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!eventId) return res.status(400).json({ error: 'Invalid event id' });

  const client = await pool.connect();
  try {
    const own = await client.query(`SELECT created_by FROM events WHERE id = $1`, [eventId]);
    if (own.rowCount === 0) return res.status(404).json({ error: 'Event not found' });
    const ownerId = (own.rows[0] as { created_by: string | null }).created_by;
    if (!ownerId || ownerId !== me) {
      return res.status(403).json({ error: 'Только создатель может управлять черным списком' });
    }

    const r = await client.query(
      `SELECT COUNT(*)::int AS count FROM event_blacklist WHERE event_id = $1`,
      [eventId],
    );
    const count = (r.rows[0]?.count as number) ?? 0;
    return res.json({ count });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.get('/:id/blacklist', authMiddleware, async (req: AuthRequest, res) => {
  const eventId = String(req.params.id);
  const me = req.user?.id;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!eventId) return res.status(400).json({ error: 'Invalid event id' });

  const client = await pool.connect();
  try {
    const own = await client.query(`SELECT created_by FROM events WHERE id = $1`, [eventId]);
    if (own.rowCount === 0) return res.status(404).json({ error: 'Event not found' });
    const ownerId = (own.rows[0] as { created_by: string | null }).created_by;
    if (!ownerId || ownerId !== me) {
      return res.status(403).json({ error: 'Только создатель может управлять черным списком' });
    }

    const r = await client.query(
      `
      SELECT u.id, u.email, u.username, u.display_name, u.avatar_url, u.status, bl.created_at
      FROM event_blacklist bl
      JOIN users u ON u.id = bl.user_id
      WHERE bl.event_id = $1
      ORDER BY bl.created_at DESC
      `,
      [eventId],
    );
    return res.json({ users: r.rows });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.post('/:id/blacklist', authMiddleware, async (req: AuthRequest, res) => {
  const eventId = String(req.params.id);
  const me = req.user?.id;
  const { userId } = req.body as { userId?: string };
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!eventId) return res.status(400).json({ error: 'Invalid event id' });
  if (!userId || typeof userId !== 'string') return res.status(400).json({ error: 'Укажите userId' });
  if (userId === me) return res.status(400).json({ error: 'Нельзя добавить себя' });

  const client = await pool.connect();
  try {
    const own = await client.query(`SELECT created_by FROM events WHERE id = $1`, [eventId]);
    if (own.rowCount === 0) return res.status(404).json({ error: 'Event not found' });
    const ownerId = (own.rows[0] as { created_by: string | null }).created_by;
    if (!ownerId || ownerId !== me) {
      return res.status(403).json({ error: 'Только создатель может управлять черным списком' });
    }

    await client.query(
      `
      INSERT INTO event_blacklist (event_id, user_id, added_by)
      VALUES ($1, $2, $3)
      ON CONFLICT (event_id, user_id) DO NOTHING
      `,
      [eventId, userId, me],
    );
    // снимаем RSVP у пользователя, чтобы он перестал быть участником
    await client.query(`DELETE FROM event_rsvp WHERE event_id = $1 AND user_id = $2`, [eventId, userId]);
    return res.status(201).json({ ok: true });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.delete('/:id/blacklist/:userId', authMiddleware, async (req: AuthRequest, res) => {
  const eventId = String(req.params.id);
  const me = req.user?.id;
  const userId = String(req.params.userId);
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!eventId) return res.status(400).json({ error: 'Invalid event id' });
  if (!userId) return res.status(400).json({ error: 'Invalid userId' });

  const client = await pool.connect();
  try {
    const own = await client.query(`SELECT created_by FROM events WHERE id = $1`, [eventId]);
    if (own.rowCount === 0) return res.status(404).json({ error: 'Event not found' });
    const ownerId = (own.rows[0] as { created_by: string | null }).created_by;
    if (!ownerId || ownerId !== me) {
      return res.status(403).json({ error: 'Только создатель может управлять черным списком' });
    }

    await client.query(`DELETE FROM event_blacklist WHERE event_id = $1 AND user_id = $2`, [eventId, userId]);
    return res.json({ ok: true });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Редактирование события (только создатель)
router.put('/:id', authMiddleware, async (req: AuthRequest, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const {
    title,
    description,
    markerColorValue,
    markerIconCode,
  } = req.body as {
    title?: string;
    description?: string;
    markerColorValue?: number;
    markerIconCode?: number;
  };

  const client = await pool.connect();
  try {
    const ownership = await client.query(
      'SELECT created_by FROM events WHERE id = $1',
      [id],
    );
    if (ownership.rowCount === 0) {
      return res.status(404).json({ error: 'Event not found' });
    }

    const ownerId = (ownership.rows[0] as { created_by: string | null }).created_by;
    if (!ownerId || ownerId !== userId) {
      return res.status(403).json({ error: 'Только создатель может редактировать событие' });
    }

    const updated = await client.query(
      `
      UPDATE events
      SET title = COALESCE($2, title),
          description = COALESCE($3, description),
          marker_color_value = COALESCE($4, marker_color_value),
          marker_icon_code = COALESCE($5, marker_icon_code)
      WHERE id = $1
      RETURNING id, title, description, image_url, lat, lon,
                marker_color_value, marker_icon_code, created_at, ends_at,
                created_by AS created_by_user_id
      `,
      [id, title ?? null, description ?? null, markerColorValue ?? null, markerIconCode ?? null],
    );

    const row = updated.rows[0] as Record<string, unknown> | undefined;
    if (!row) {
      return res.status(404).json({ error: 'Event not found' });
    }

    if (row.created_by_user_id) {
      const creatorResult = await client.query(
        `
        SELECT email, username, display_name
        FROM users
        WHERE id = $1
        `,
        [row.created_by_user_id as string],
      );
      const creator = creatorResult.rows[0] as
        | { email?: string; username?: string; display_name?: string }
        | undefined;
      if (creator) {
        row.created_by_email = creator.email ?? null;
        row.created_by_username = creator.username ?? null;
        row.created_by_display_name = creator.display_name ?? null;
      }
    }

    const going = await client.query(
      `
      SELECT u.id, u.email, u.username, u.display_name, u.avatar_url, u.status
      FROM event_rsvp r
      JOIN users u ON u.id = r.user_id
      WHERE r.event_id = $1 AND r.status = 1
      ORDER BY r.updated_at ASC
      `,
      [id],
    );
    const notGoing = await client.query(
      `
      SELECT u.id, u.email, u.username, u.display_name, u.avatar_url, u.status
      FROM event_rsvp r
      JOIN users u ON u.id = r.user_id
      WHERE r.event_id = $1 AND r.status = -1
      ORDER BY r.updated_at ASC
      `,
      [id],
    );
    row.going_users = going.rows;
    row.not_going_users = notGoing.rows;

    return res.json(row);
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
    const bl = await client.query(
      `SELECT 1 FROM event_blacklist WHERE event_id = $1 AND user_id = $2`,
      [eventId, userId],
    );
    if ((bl.rowCount ?? 0) > 0) {
      return res.status(403).json({ error: 'Доступ запрещён' });
    }

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
      `SELECT u.id, u.email, u.username, u.display_name, u.avatar_url, u.status
       FROM event_rsvp r JOIN users u ON u.id = r.user_id
       WHERE r.event_id = $1 AND r.status = 1 ORDER BY r.updated_at ASC`,
      [eventId],
    );
    const notGoing = await client.query(
      `SELECT u.id, u.email, u.username, u.display_name, u.avatar_url, u.status
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

// Отправить сообщение в чат события — только для участников (RSVP «приду»)
router.post('/:id/messages', authMiddleware, async (req: AuthRequest, res) => {
  const idParam = req.params.id;
  const eventId = (Array.isArray(idParam) ? idParam[0] : idParam) ?? '';
  if (!eventId) {
    return res.status(400).json({ error: 'Invalid event id' });
  }
  const userId = req.user?.id;
  const { text, reply_to_id: replyToIdRaw } = req.body as {
    text?: string;
    reply_to_id?: string | null;
  };
  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  if (!text || typeof text !== 'string' || text.trim() === '') {
    return res.status(400).json({ error: 'Текст сообщения обязателен' });
  }
  let replyToId: string | null = null;
  if (replyToIdRaw != null && replyToIdRaw !== '') {
    if (typeof replyToIdRaw !== 'string') {
      return res.status(400).json({ error: 'Некорректный reply_to_id' });
    }
    replyToId = replyToIdRaw;
  }
  const client = await pool.connect();
  try {
    const bl = await client.query(
      `SELECT 1 FROM event_blacklist WHERE event_id = $1 AND user_id = $2`,
      [eventId, userId],
    );
    if ((bl.rowCount ?? 0) > 0) {
      return res.status(403).json({ error: 'Доступ запрещён' });
    }

    const participant = await client.query(
      'SELECT 1 FROM event_rsvp WHERE event_id = $1 AND user_id = $2 AND status = 1',
      [eventId, userId],
    );
    if (participant.rowCount === 0) {
      return res.status(403).json({ error: 'Вы не участвуете в этом событии' });
    }
    if (replyToId) {
      const anchor = await client.query(
        `SELECT 1 FROM event_messages WHERE id = $1 AND event_id = $2`,
        [replyToId, eventId],
      );
      if (anchor.rowCount === 0) {
        return res.status(400).json({ error: 'Сообщение для ответа не найдено' });
      }
    }
    const result = await client.query(
      `
      WITH ins AS (
        INSERT INTO event_messages (event_id, user_id, text, reply_to_id)
        VALUES ($1, $2, $3, $4)
        RETURNING *
      )
      SELECT ins.id,
             ins.event_id,
             ins.user_id,
             ins.text,
             ins.created_at,
             ins.edited_at,
             ins.reply_to_id,
             u.email AS user_email,
             u.display_name AS user_display_name,
             u.avatar_url AS avatar_url,
             reply_msg.text AS reply_to_text,
             ru.display_name AS reply_to_author_name,
             ru.email AS reply_to_author_email
      FROM ins
      LEFT JOIN users u ON u.id = ins.user_id
      LEFT JOIN event_messages reply_msg ON reply_msg.id = ins.reply_to_id
      LEFT JOIN users ru ON ru.id = reply_msg.user_id
      `,
      [eventId, userId, encryptMessageText(text.trim()), replyToId],
    );
    const row = result.rows[0] as Record<string, unknown>;
    (row as any).text = decryptMessageText((row as any).text);
    (row as any).reply_to_text = decryptMessageText((row as any).reply_to_text);
    (row as Record<string, unknown>).is_viewed = false;

    const socketIo = (req as unknown as { app: { get: (key: string) => unknown } }).app.get('io');
    if (socketIo && typeof (socketIo as { to: (room: string) => { emit: (ev: string, data: unknown) => void } }).to === 'function') {
      (socketIo as { to: (room: string) => { emit: (ev: string, data: unknown) => void } }).to(`event:${eventId}`).emit('newMessage', row);
    }

    const titleR = await client.query(`SELECT title FROM events WHERE id = $1`, [eventId]);
    const eventTitle = String(titleR.rows[0]?.title ?? '').trim();
    const dn = String(row.user_display_name ?? '').trim();
    const em = String(row.user_email ?? '').trim();
    const senderLabel = dn || em || 'Участник';
    void notifyEventChatMessage({
      eventId,
      eventTitle,
      messageId: row.id as string,
      senderUserId: userId,
      senderLabel,
      text: text.trim(),
    });

    return res.status(201).json(row);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Отметить сообщения как прочитанные (просмотренные) в чате события
// Тело: { up_to_id: string } — отметить все чужие сообщения до этого (включительно)
router.post('/:id/messages/view', authMiddleware, async (req: AuthRequest, res) => {
  const { id: eventId } = req.params;
  const userId = req.user?.id;
  const { up_to_id: upToId } = (req.body ?? {}) as { up_to_id?: string };

  if (!userId) return res.status(401).json({ error: 'Unauthorized' });
  if (!upToId || typeof upToId !== 'string') {
    return res.status(400).json({ error: 'up_to_id обязателен' });
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

    const anchor = await client.query(
      `SELECT id, created_at FROM event_messages WHERE id = $1 AND event_id = $2`,
      [upToId, eventId],
    );
    if (anchor.rowCount === 0) {
      return res.status(404).json({ error: 'Message not found' });
    }
    const upToCreatedAt = anchor.rows[0].created_at as Date;

    await client.query(
      `
      INSERT INTO event_message_views (message_id, user_id, viewed_at)
      SELECT m.id, $2, now()
      FROM event_messages m
      WHERE m.event_id = $1
        AND m.user_id <> $2
        AND (m.created_at <= $3 OR m.id = $4)
      ON CONFLICT (message_id, user_id)
      DO UPDATE SET viewed_at = EXCLUDED.viewed_at
      `,
      [eventId, userId, upToCreatedAt, upToId],
    );

    const socketIo = (req as unknown as { app: { get: (key: string) => unknown } }).app.get('io');
    if (socketIo && typeof (socketIo as { to: (room: string) => { emit: (ev: string, data: unknown) => void } }).to === 'function') {
      (socketIo as { to: (room: string) => { emit: (ev: string, data: unknown) => void } })
        .to(`event:${eventId}`)
        .emit('messagesViewed', { event_id: eventId, user_id: userId, up_to_id: upToId });
    }

    return res.json({ success: true });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Текущий mute push-уведомлений для чата события
router.get('/:id/mute', authMiddleware, async (req: AuthRequest, res) => {
  const { id: eventId } = req.params;
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });
  if (!eventId) return res.status(400).json({ error: 'Invalid event id' });

  const client = await pool.connect();
  try {
    const r = await client.query(
      `
      SELECT muted_until
      FROM user_event_chat_mutes
      WHERE user_id = $1 AND event_id = $2
      `,
      [userId, eventId],
    );
    const mutedUntil = (r.rows[0]?.muted_until as Date | null | undefined) ?? null;
    return res.json({ muted_until: mutedUntil ? mutedUntil.toISOString() : null });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Установить/сбросить mute push-уведомлений для чата события
router.post('/:id/mute', authMiddleware, async (req: AuthRequest, res) => {
  const { id: eventId } = req.params;
  const userId = req.user?.id;
  const { muted_until } = (req.body ?? {}) as { muted_until?: string | null };
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });
  if (!eventId) return res.status(400).json({ error: 'Invalid event id' });

  let parsed: Date | null = null;
  if (muted_until === null) {
    parsed = null;
  } else if (muted_until === undefined) {
    return res.status(400).json({ error: 'muted_until обязателен (ISO строка или null)' });
  } else if (typeof muted_until !== 'string' || muted_until.trim() === '') {
    return res.status(400).json({ error: 'muted_until: некорректное значение' });
  } else {
    const d = new Date(muted_until);
    if (Number.isNaN(d.getTime())) {
      return res.status(400).json({ error: 'muted_until: некорректный ISO формат' });
    }
    parsed = d;
  }

  const client = await pool.connect();
  try {
    await client.query(
      `
      INSERT INTO user_event_chat_mutes (user_id, event_id, muted_until, updated_at)
      VALUES ($1, $2, $3, now())
      ON CONFLICT (user_id, event_id)
      DO UPDATE SET muted_until = EXCLUDED.muted_until, updated_at = now()
      `,
      [userId, eventId, parsed],
    );
    return res.json({ success: true, muted_until: parsed ? parsed.toISOString() : null });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Сообщения по событию — только для участников (RSVP «приду»)
router.get('/:id/messages', authMiddleware, async (req: AuthRequest, res) => {
  const { id: eventId } = req.params;
  const userId = req.user?.id;
  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  const client = await pool.connect();
  try {
    const bl = await client.query(
      `SELECT 1 FROM event_blacklist WHERE event_id = $1 AND user_id = $2`,
      [eventId, userId],
    );
    if ((bl.rowCount ?? 0) > 0) {
      return res.status(403).json({ error: 'Доступ запрещён' });
    }

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
            u.display_name AS user_display_name,
            u.avatar_url AS avatar_url,
            m.text,
            m.created_at,
            m.edited_at,
            m.reply_to_id,
            reply_msg.text AS reply_to_text,
            ru.display_name AS reply_to_author_name,
            ru.email AS reply_to_author_email,
            CASE
              WHEN m.user_id = $2 THEN EXISTS (
                SELECT 1
                FROM event_message_views v
                WHERE v.message_id = m.id AND v.user_id <> $2
              )
              ELSE EXISTS (
                SELECT 1
                FROM event_message_views v
                WHERE v.message_id = m.id AND v.user_id = $2
              )
            END AS is_viewed,
            (
              SELECT v.viewed_at
              FROM event_message_views v
              WHERE v.message_id = m.id AND v.user_id = $2
              LIMIT 1
            ) AS viewed_at
      FROM event_messages m
      LEFT JOIN users u ON u.id = m.user_id
      LEFT JOIN event_messages reply_msg ON reply_msg.id = m.reply_to_id
      LEFT JOIN users ru ON ru.id = reply_msg.user_id
      WHERE m.event_id = $1
      ORDER BY m.created_at ASC
      `,
      [eventId, userId],
    );
    const rows = result.rows.map((r) => ({
      ...r,
      text: decryptMessageText((r as any).text),
      reply_to_text: decryptMessageText((r as any).reply_to_text),
    }));
    return res.json(rows);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Изменить своё сообщение в чате события
router.put('/:id/messages/:messageId', authMiddleware, async (req: AuthRequest, res) => {
  const { id: eventId, messageId } = req.params;
  const userId = req.user?.id;
  const { text } = req.body as { text?: string };
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });
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
    const upd = await client.query(
      `
      WITH updated AS (
        UPDATE event_messages
        SET text = $1, edited_at = now()
        WHERE id = $2 AND event_id = $3 AND user_id = $4
        RETURNING *
      )
      SELECT updated.id,
             updated.event_id,
             updated.user_id,
             updated.text,
             updated.created_at,
             updated.edited_at,
             updated.reply_to_id,
             usr.email AS user_email,
             usr.display_name AS user_display_name,
             usr.avatar_url AS avatar_url,
             reply_msg.text AS reply_to_text,
             ru.display_name AS reply_to_author_name,
             ru.email AS reply_to_author_email
      FROM updated
      LEFT JOIN users usr ON usr.id = updated.user_id
      LEFT JOIN event_messages reply_msg ON reply_msg.id = updated.reply_to_id
      LEFT JOIN users ru ON ru.id = reply_msg.user_id
      `,
      [encryptMessageText(text.trim()), messageId, eventId, userId],
    );
    if (upd.rowCount === 0) {
      return res.status(404).json({ error: 'Сообщение не найдено или не ваше' });
    }
    const row = upd.rows[0] as Record<string, unknown>;
    (row as any).text = decryptMessageText((row as any).text);
    (row as any).reply_to_text = decryptMessageText((row as any).reply_to_text);

    const socketIo = (req as unknown as { app: { get: (key: string) => unknown } }).app.get('io');
    if (socketIo && typeof (socketIo as { to: (room: string) => { emit: (ev: string, data: unknown) => void } }).to === 'function') {
      const r = row as Record<string, unknown>;
      const toIso = (v: unknown) =>
        v instanceof Date ? v.toISOString() : v != null ? String(v) : null;
      const payload = {
        ...r,
        id: String(r.id),
        created_at: toIso(r.created_at),
        edited_at: toIso(r.edited_at),
      };
      (socketIo as { to: (room: string) => { emit: (ev: string, data: unknown) => void } })
        .to(`event:${eventId}`)
        .emit('messageUpdated', payload);
    }
    return res.json(row);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Удалить сообщение: автор или организатор события
router.delete('/:id/messages/:messageId', authMiddleware, async (req: AuthRequest, res) => {
  const { id: eventId, messageId } = req.params;
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });
  const client = await pool.connect();
  try {
    const participant = await client.query(
      'SELECT 1 FROM event_rsvp WHERE event_id = $1 AND user_id = $2 AND status = 1',
      [eventId, userId],
    );
    if (participant.rowCount === 0) {
      return res.status(403).json({ error: 'Вы не участвуете в этом событии' });
    }
    const del = await client.query(
      `
      DELETE FROM event_messages m
      WHERE m.id = $1 AND m.event_id = $2
        AND (
          m.user_id = $3
          OR EXISTS (
            SELECT 1 FROM events e
            WHERE e.id = m.event_id AND e.created_by = $3
          )
        )
      RETURNING m.id
      `,
      [messageId, eventId, userId],
    );
    if (del.rowCount === 0) {
      return res.status(404).json({ error: 'Сообщение не найдено или нет прав' });
    }
    const socketIo = (req as unknown as { app: { get: (key: string) => unknown } }).app.get('io');
    if (socketIo && typeof (socketIo as { to: (room: string) => { emit: (ev: string, data: unknown) => void } }).to === 'function') {
      (socketIo as { to: (room: string) => { emit: (ev: string, data: unknown) => void } })
        .to(`event:${eventId}`)
        .emit('messageDeleted', { event_id: eventId, id: messageId });
    }
    return res.json({ success: true });
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
                marker_color_value, marker_icon_code, created_at, ends_at,
                created_by AS created_by_user_id
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
    const creatorUserId = req.user?.id;
    if (creatorUserId && created?.id) {
      await client.query(
        `
        INSERT INTO event_rsvp (event_id, user_id, status)
        VALUES ($1, $2, 1)
        ON CONFLICT (event_id, user_id)
        DO UPDATE SET status = 1, updated_at = now()
        `,
        [created.id, creatorUserId],
      );
    }
    if (created?.created_by_user_id) {
      const creatorResult = await client.query(
        `
        SELECT email, username, display_name
        FROM users
        WHERE id = $1
        `,
        [created.created_by_user_id],
      );
      const creator = creatorResult.rows[0];
      if (creator) {
        created.created_by_email = creator.email;
        created.created_by_username = creator.username;
        created.created_by_display_name = creator.display_name;
      }
    }
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

