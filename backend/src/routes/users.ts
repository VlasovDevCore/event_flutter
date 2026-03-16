import { Router } from 'express';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../middleware/auth';

const router = Router();

// Поиск пользователей (для добавления в друзья): по email, исключая себя, уже друзей и с ожидающими заявками
router.get('/search', authMiddleware, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  const q = (req.query.q as string)?.trim() ?? '';
  if (!userId) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const result = await client.query(
      `
      SELECT u.id, u.email
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

export default router;
