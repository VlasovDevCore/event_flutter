import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import type { PoolClient } from 'pg';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../middleware/auth';
import { buildAchievementsFromStats, type UserEventStats } from '../achievementRules';

const router = Router();

async function getUserEventStats(client: PoolClient, userId: string): Promise<UserEventStats> {
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
          ON r.event_id = e.id
          AND r.status = 1
          AND r.user_id <> e.created_by
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

  const eventsIGoingAsGuest = await client.query(
    `
      SELECT COUNT(*)::int AS count
      FROM event_rsvp r
      INNER JOIN events e ON e.id = r.event_id
      WHERE r.user_id = $1
        AND r.status = 1
        AND e.created_by IS NOT NULL
        AND e.created_by <> r.user_id
      `,
    [userId],
  );

  const followers = await client.query(
    `SELECT COUNT(*)::int AS count FROM friend_requests WHERE to_user_id = $1`,
    [userId],
  );

  return {
    created_events_count: (createdEvents.rows[0] as { count: number }).count,
    total_going_to_my_events_count: (totalGoingToMyEvents.rows[0] as { count: number }).count,
    events_i_going_count: (eventsIGoing.rows[0] as { count: number }).count,
    events_i_going_as_guest_count: (eventsIGoingAsGuest.rows[0] as { count: number }).count,
    followers_count: (followers.rows[0] as { count: number }).count,
  };
}

const avatarsBaseDir = path.join(process.cwd(), 'uploads', 'avatars');
const uploadsDir = path.join(process.cwd(), 'uploads');
try {
  fs.mkdirSync(avatarsBaseDir, { recursive: true });
} catch {
  // ignore
}

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

async function tryDeleteOldAvatar(client: PoolClient, userId: string): Promise<void> {
  const r = await client.query(`SELECT avatar_url FROM users WHERE id = $1`, [userId]);
  const old = (r.rows[0]?.avatar_url as string | null | undefined) ?? null;
  if (!old) return;
  // delete only our uploaded avatars
  if (!old.startsWith('/uploads/avatars/')) return;
  const abs = resolveUploadsFilePathFromUrl(old);
  if (!abs) return;
  try {
    await fs.promises.unlink(abs);
  } catch {
    // ignore (already deleted or inaccessible)
  }
}

function todayFolderName() {
  // YYYY-MM-DD (UTC), чтобы имя папки было консистентным
  return new Date().toISOString().slice(0, 10);
}

const HEX6 = /^#[0-9A-Fa-f]{6}$/;

/** 3 hex-цвета #RRGGBB или null (сброс). undefined — поле не трогать. */
function parseCoverGradientColors(input: unknown): string[] | null | undefined {
  if (input === undefined) return undefined;
  if (input === null) return null;
  if (!Array.isArray(input) || input.length !== 3) return undefined;
  const out: string[] = [];
  for (const x of input) {
    if (typeof x !== 'string' || !HEX6.test(x)) return undefined;
    out.push(x);
  }
  return out;
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
             avatar_url,
             cover_gradient_colors,
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
      await tryDeleteOldAvatar(client, userId);
      const result = await client.query(
        `UPDATE users SET avatar_url = $1 WHERE id = $2
         RETURNING id, email, status, username, display_name, bio, birth_date, gender, avatar_url, cover_gradient_colors, created_at`,
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
    allowMessagesFromNonFriends,
    coverGradientColors,
  } = req.body as {
    username?: string | null;
    displayName?: string | null;
    bio?: string | null;
    birthDate?: string | null; // YYYY-MM-DD
    gender?: string | null;
    allowMessagesFromNonFriends?: boolean | null;
    coverGradientColors?: string[] | null;
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

  const normalizedAllowMessages =
    allowMessagesFromNonFriends === undefined ? undefined : Boolean(allowMessagesFromNonFriends);

  const parsedCoverGradient = parseCoverGradientColors(coverGradientColors);
  if (coverGradientColors !== undefined && parsedCoverGradient === undefined) {
    return res.status(400).json({ error: 'Invalid coverGradientColors (need 3 strings like #RRGGBB)' });
  }

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

    type SetField = { sql: string; value: unknown; suffix?: string };
    const fields: SetField[] = [];
    const add = (sql: string, value: unknown, suffix?: string) => {
      const row: SetField = { sql, value };
      if (suffix !== undefined) row.suffix = suffix;
      fields.push(row);
    };

    if (normalizedUsername !== undefined) add('username = $', normalizedUsername);
    if (normalizedDisplayName !== undefined) add('display_name = $', normalizedDisplayName);
    if (normalizedBio !== undefined) add('bio = $', normalizedBio);
    if (birthDateSql !== undefined) add('birth_date = $', birthDateSql);
    if (normalizedGender !== undefined) add('gender = $', normalizedGender);
    if (normalizedAllowMessages !== undefined) add('allow_messages_from_non_friends = $', normalizedAllowMessages);
    if (parsedCoverGradient !== undefined) {
      add(
        'cover_gradient_colors = $',
        parsedCoverGradient === null ? null : JSON.stringify(parsedCoverGradient),
        '::jsonb',
      );
    }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'Nothing to update' });
    }

    const sets = fields.map((f, idx) => `${f.sql}${idx + 1}${f.suffix ?? ''}`).join(', ');
    const values = fields.map((f) => f.value);
    values.push(userId);

    const result = await client.query(
      `
      UPDATE users
      SET ${sets}
      WHERE id = $${fields.length + 1}
      RETURNING id, email, status, username, display_name, bio, birth_date, gender, avatar_url, cover_gradient_colors, allow_messages_from_non_friends, created_at
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
    const stats = await getUserEventStats(client, userId);
    return res.json(stats);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Мой профиль: достижения (на основе статистики)
router.get('/me/achievements', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const stats = await getUserEventStats(client, userId);
    return res.json({ achievements: buildAchievementsFromStats(stats) });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Регистрация FCM-токена устройства (push о новых сообщениях)
router.post('/me/push-token', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  const { token, platform } = req.body as { token?: string; platform?: string };
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });
  if (!token || typeof token !== 'string' || token.trim() === '') {
    return res.status(400).json({ error: 'token обязателен' });
  }
  const p =
    platform === 'ios' ? 'ios' : platform === 'web' ? 'web' : 'android';

  const client = await pool.connect();
  try {
    await client.query(
      `
      INSERT INTO user_push_tokens (user_id, token, platform, updated_at)
      VALUES ($1, $2, $3, now())
      ON CONFLICT (user_id, token)
      DO UPDATE SET platform = EXCLUDED.platform, updated_at = now()
      `,
      [userId, token.trim(), p],
    );
    return res.json({ success: true });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.delete('/me/push-token', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  const { token } = req.body as { token?: string };
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });
  if (!token || typeof token !== 'string' || token.trim() === '') {
    return res.status(400).json({ error: 'token обязателен' });
  }

  const client = await pool.connect();
  try {
    await client.query(`DELETE FROM user_push_tokens WHERE user_id = $1 AND token = $2`, [
      userId,
      token.trim(),
    ]);
    return res.json({ success: true });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

router.get('/check-username', async (req, res) => {
  const { username } = req.query;
  
  if (!username || typeof username !== 'string') {
    return res.status(400).json({ error: 'Username is required' });
  }
  
  if (!/^[a-zA-Z0-9._]{3,20}$/.test(username)) {
    return res.status(400).json({ error: 'Invalid username format' });
  }
  
  const client = await pool.connect();
  try {
    const result = await client.query(
      'SELECT id FROM users WHERE username = $1',
      [username]
    );
    
    if (result.rowCount && result.rowCount > 0) {
      return res.status(409).json({ 
        error: 'Username already taken',
        available: false 
      });
    }
    
    return res.status(200).json({ 
      available: true,
      message: 'Username is available' 
    });
  } catch (err) {
    console.error('Error checking username:', err);
    return res.status(500).json({ error: 'Internal server error' });
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
    const stats = await getUserEventStats(client, userId);
    return res.json(stats);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Публичные достижения пользователя (для просмотра профиля)
router.get('/:id/achievements', async (req, res) => {
  const { id: userId } = req.params;
  const client = await pool.connect();
  try {
    const exists = await client.query('SELECT 1 FROM users WHERE id = $1', [userId]);
    if (exists.rowCount === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    const stats = await getUserEventStats(client, userId);
    return res.json({ achievements: buildAchievementsFromStats(stats) });
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
             avatar_url,
             cover_gradient_colors,
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
