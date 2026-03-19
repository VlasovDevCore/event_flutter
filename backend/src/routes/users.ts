import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../middleware/auth';

const router = Router();

const avatarsBaseDir = path.join(process.cwd(), 'uploads', 'avatars');
const uploadsDir = path.join(process.cwd(), 'uploads');
try {
  fs.mkdirSync(avatarsBaseDir, { recursive: true });
} catch {
  // ignore
}

function todayFolderName() {
  // YYYY-MM-DD (UTC), чтобы имя папки было консистентным
  return new Date().toISOString().slice(0, 10);
}

const uploadAvatar = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => {
      const dayDir = path.join(avatarsBaseDir, todayFolderName());
      try {
        fs.mkdirSync(dayDir, { recursive: true });
      } catch {
        // ignore
      }
      cb(null, dayDir);
    },
    filename: (req, file, cb) => {
      const userId = (req as AuthRequest).user?.id ?? 'unknown';
      const ext = path.extname(file.originalname || '') || '.jpg';
      const safeExt = ext.length <= 8 ? ext : '.jpg';
      cb(null, `${userId}-${Date.now()}${safeExt}`);
    },
  }),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB
  },
  fileFilter: (_req, file, cb) => {
    // Flutter иногда отправляет multipart как application/octet-stream,
    // поэтому опираемся не только на mimetype, но и на расширение имени.
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

// Мой профиль: данные (username/email)
router.get('/me', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const result = await client.query(
      `
      SELECT id,
             email,
             status,
             username,
             display_name,
             bio,
             birth_date,
             gender,
             avatar_color_value,
             avatar_icon_code,
             avatar_url,
             allow_messages_from_non_friends,
             created_at
      FROM users
      WHERE id = $1
      `,
      [userId],
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    return res.json(result.rows[0]);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Загрузить аватар (multipart/form-data, field name: avatar)
router.post(
  '/me/avatar',
  authMiddleware,
  uploadAvatar.single('avatar'),
  async (req: AuthRequest, res) => {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ error: 'Unauthorized' });
    if (!req.file) return res.status(400).json({ error: 'avatar is required' });

    // req.file.destination указывает реальный путь на диске (например: .../uploads/avatars/2026-03-19)
    // Конвертим в URL-формат с прямыми слешами.
    const fileDestination = (req.file as any).destination as string | undefined;
    const relToUploads =
      fileDestination != null ? path.relative(uploadsDir, fileDestination) : null;
    const relToUploadsUrl =
      relToUploads != null ? relToUploads.split(path.sep).join('/') : 'avatars';
    const relativeUrl = `/uploads/${relToUploadsUrl}/${req.file.filename}`;
    const client = await pool.connect();
    try {
      const result = await client.query(
        `UPDATE users SET avatar_url = $1 WHERE id = $2
         RETURNING id, email, status, username, display_name, bio, birth_date, gender, avatar_color_value, avatar_icon_code, avatar_url, created_at`,
        [relativeUrl, userId],
      );
      return res.json(result.rows[0]);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(err);
      return res.status(500).json({ error: 'Internal error' });
    } finally {
      client.release();
    }
  },
);

// Мой профиль: обновить username
router.put('/me', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const {
    username,
    displayName,
    bio,
    birthDate,
    gender,
    avatarColorValue,
    avatarIconCodePoint,
    allowMessagesFromNonFriends,
  } = req.body as {
    username?: string | null;
    displayName?: string | null;
    bio?: string | null;
    birthDate?: string | null; // YYYY-MM-DD
    gender?: string | null;
    avatarColorValue?: number | string | null;
    avatarIconCodePoint?: number | string | null;
    allowMessagesFromNonFriends?: boolean | null;
  };

  const normalizedUsername =
    username === undefined
      ? undefined
      : username === null
          ? null
          : typeof username === 'string'
              ? username.trim()
              : undefined;

  if (normalizedUsername !== undefined && normalizedUsername !== null) {
    if (normalizedUsername.length < 3 || normalizedUsername.length > 24) {
      return res.status(400).json({ error: 'Invalid username' });
    }
    if (!/^[a-zA-Z0-9_]+$/.test(normalizedUsername)) {
      return res.status(400).json({ error: 'Invalid username' });
    }
  }

  const normalizedDisplayName =
    displayName === undefined
      ? undefined
      : displayName === null
          ? null
          : typeof displayName === 'string'
              ? displayName.trim()
              : undefined;
  if (normalizedDisplayName !== undefined && normalizedDisplayName !== null) {
    if (normalizedDisplayName.length < 1 || normalizedDisplayName.length > 40) {
      return res.status(400).json({ error: 'Invalid displayName' });
    }
  }

  const normalizedBio =
    bio === undefined
      ? undefined
      : bio === null
          ? null
          : typeof bio === 'string'
              ? bio.trim()
              : undefined;
  if (normalizedBio !== undefined && normalizedBio !== null) {
    if (normalizedBio.length > 500) {
      return res.status(400).json({ error: 'Bio is too long' });
    }
  }

  const normalizedGender =
    gender === undefined
      ? undefined
      : gender === null
          ? null
          : typeof gender === 'string'
              ? gender.trim()
              : undefined;
  if (normalizedGender !== undefined && normalizedGender !== null) {
    if (normalizedGender.length > 24) {
      return res.status(400).json({ error: 'Invalid gender' });
    }
  }

  const normalizedBirthDate =
    birthDate === undefined
      ? undefined
      : birthDate === null
          ? null
          : typeof birthDate === 'string'
              ? birthDate.trim()
              : undefined;
  let birthDateSql: string | null | undefined = normalizedBirthDate;
  if (normalizedBirthDate !== undefined && normalizedBirthDate !== null) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(normalizedBirthDate)) {
      return res.status(400).json({ error: 'Invalid birthDate' });
    }
    birthDateSql = normalizedBirthDate;
  }

  const parseBigintLike = (v: number | string | null | undefined) => {
    if (v === undefined) return undefined;
    if (v === null) return null;
    const n = typeof v === 'number' ? v : Number(v);
    if (!Number.isFinite(n)) return undefined;
    return Math.trunc(n);
  };

  const normalizedAvatarColorValue = parseBigintLike(avatarColorValue);
  const normalizedAvatarIconCode = parseBigintLike(avatarIconCodePoint);
  const normalizedAllowMessages =
    allowMessagesFromNonFriends === undefined ? undefined : Boolean(allowMessagesFromNonFriends);

  const client = await pool.connect();
  try {
    if (normalizedUsername) {
      const existingUsername = await client.query(
        'SELECT 1 FROM users WHERE username = $1 AND id != $2',
        [normalizedUsername, userId],
      );
      if (existingUsername.rowCount && existingUsername.rowCount > 0) {
        return res.status(409).json({ error: 'Username already taken' });
      }
    }

    const fields: { sql: string; value: unknown }[] = [];
    const add = (sql: string, value: unknown) => fields.push({ sql, value });

    if (normalizedUsername !== undefined) add('username = $', normalizedUsername);
    if (normalizedDisplayName !== undefined) add('display_name = $', normalizedDisplayName);
    if (normalizedBio !== undefined) add('bio = $', normalizedBio);
    if (birthDateSql !== undefined) add('birth_date = $', birthDateSql);
    if (normalizedGender !== undefined) add('gender = $', normalizedGender);
    if (normalizedAvatarColorValue !== undefined) add('avatar_color_value = $', normalizedAvatarColorValue);
    if (normalizedAvatarIconCode !== undefined) add('avatar_icon_code = $', normalizedAvatarIconCode);
    if (normalizedAllowMessages !== undefined) add('allow_messages_from_non_friends = $', normalizedAllowMessages);

    if (fields.length === 0) {
      return res.status(400).json({ error: 'Nothing to update' });
    }

    const sets = fields.map((f, idx) => `${f.sql}${idx + 1}`).join(', ');
    const values = fields.map((f) => f.value);
    values.push(userId);

    const result = await client.query(
      `
      UPDATE users
      SET ${sets}
      WHERE id = $${fields.length + 1}
      RETURNING id, email, status, username, display_name, bio, birth_date, gender, avatar_color_value, avatar_icon_code, avatar_url, allow_messages_from_non_friends, created_at
      `,
      values,
    );
    return res.json(result.rows[0]);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Мой профиль: статистика по событиям
router.get('/me/stats', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const createdEvents = await client.query(
      `SELECT COUNT(*)::int AS count FROM events WHERE created_by = $1`,
      [userId],
    );

    const totalGoingToMyEvents = await client.query(
      `
      SELECT COALESCE(SUM(x.going_count), 0)::int AS count
      FROM (
        SELECT COUNT(r.user_id)::int AS going_count
        FROM events e
        LEFT JOIN event_rsvp r
          ON r.event_id = e.id AND r.status = 1
        WHERE e.created_by = $1
        GROUP BY e.id
      ) x
      `,
      [userId],
    );

    const eventsIGoing = await client.query(
      `SELECT COUNT(*)::int AS count FROM event_rsvp WHERE user_id = $1 AND status = 1`,
      [userId],
    );

    const followers = await client.query(
      `SELECT COUNT(*)::int AS count FROM friend_requests WHERE to_user_id = $1`,
      [userId],
    );

    return res.json({
      created_events_count: (createdEvents.rows[0] as { count: number }).count,
      total_going_to_my_events_count: (totalGoingToMyEvents.rows[0] as { count: number }).count,
      events_i_going_count: (eventsIGoing.rows[0] as { count: number }).count,
      followers_count: (followers.rows[0] as { count: number }).count,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Поиск пользователей (для добавления в друзья): по email, исключая себя, уже друзей и с ожидающими заявками
router.get('/search', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  const q = (req.query.q as string)?.trim() ?? '';
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const result = await client.query(
      `
      SELECT u.id, u.email, u.status
      FROM users u
      WHERE u.id != $1
        AND ($2 = '' OR u.email ILIKE $3)
        AND NOT EXISTS (
          SELECT 1 FROM friend_requests fr
          WHERE (fr.from_user_id = $1 AND fr.to_user_id = u.id)
             OR (fr.from_user_id = u.id AND fr.to_user_id = $1)
        )
      ORDER BY u.email
      LIMIT 50
      `,
      [userId, q, `%${q}%`],
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

// Публичная статистика пользователя (для просмотра профиля в деталях события)
// ВАЖНО: должен быть до /:id, иначе перехватится как id=".../stats".
router.get('/:id/stats', async (req, res) => {
  const { id: userId } = req.params;
  const client = await pool.connect();
  try {
    const createdEvents = await client.query(
      `SELECT COUNT(*)::int AS count FROM events WHERE created_by = $1`,
      [userId],
    );

    const totalGoingToUserEvents = await client.query(
      `
      SELECT COALESCE(SUM(x.going_count), 0)::int AS count
      FROM (
        SELECT COUNT(r.user_id)::int AS going_count
        FROM events e
        LEFT JOIN event_rsvp r
          ON r.event_id = e.id AND r.status = 1
        WHERE e.created_by = $1
        GROUP BY e.id
      ) x
      `,
      [userId],
    );

    const eventsUserGoing = await client.query(
      `SELECT COUNT(*)::int AS count FROM event_rsvp WHERE user_id = $1 AND status = 1`,
      [userId],
    );

    const followers = await client.query(
      `SELECT COUNT(*)::int AS count FROM friend_requests WHERE to_user_id = $1`,
      [userId],
    );

    return res.json({
      created_events_count: (createdEvents.rows[0] as { count: number }).count,
      total_going_to_my_events_count: (totalGoingToUserEvents.rows[0] as { count: number }).count,
      events_i_going_count: (eventsUserGoing.rows[0] as { count: number }).count,
      followers_count: (followers.rows[0] as { count: number }).count,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Публичный профиль пользователя (для просмотра в деталях события)
// ВАЖНО: должен быть после /search, иначе перехватит этот маршрут.
router.get('/:id', async (req, res) => {
  const { id } = req.params;
  const client = await pool.connect();
  try {
    const result = await client.query(
      `
      SELECT id,
             email,
             status,
             username,
             display_name,
             bio,
             birth_date,
             gender,
             avatar_color_value,
             avatar_icon_code,
             avatar_url,
             allow_messages_from_non_friends,
             created_at
      FROM users
      WHERE id = $1
      `,
      [id],
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    return res.json(result.rows[0]);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

export default router;
