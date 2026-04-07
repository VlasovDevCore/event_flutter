import { Router } from 'express';
import { pool } from '../db';
import { authMiddleware, AuthRequest } from '../middleware/auth';
import { notifyDirectMessage } from '../services/push';
import { decryptMessageText, encryptMessageText } from '../utils/messageCrypto';

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

async function messageInConversation(
  client: { query: (q: string, p?: unknown[]) => Promise<{ rowCount: number | null }> },
  messageId: string,
  me: string,
  other: string,
) {
  const r = await client.query(
    `
    SELECT 1 FROM direct_messages
    WHERE id = $1
      AND (
        (from_user_id = $2 AND to_user_id = $3)
        OR (from_user_id = $3 AND to_user_id = $2)
      )
    `,
    [messageId, me, other],
  );
  return (r.rowCount ?? 0) > 0;
}

/** $1 = me, $2 = other — для is_viewed / viewed_at */
function directMessageSelectWithView(): string {
  return `
  SELECT m.id,
         m.from_user_id AS user_id,
         m.text,
         m.created_at,
         m.edited_at,
         m.reply_to_id,
         u.email AS user_email,
         u.display_name AS user_display_name,
         u.avatar_url AS avatar_url,
         reply_msg.text AS reply_to_text,
         ru.display_name AS reply_to_author_name,
         ru.email AS reply_to_author_email,
         CASE
           WHEN m.from_user_id = $1 THEN EXISTS (
             SELECT 1 FROM direct_message_views v
             WHERE v.message_id = m.id AND v.user_id = $2
           )
           ELSE EXISTS (
             SELECT 1 FROM direct_message_views v
             WHERE v.message_id = m.id AND v.user_id = $1
           )
         END AS is_viewed,
         (
           SELECT v.viewed_at FROM direct_message_views v
           WHERE v.message_id = m.id AND v.user_id = $1
           LIMIT 1
         ) AS viewed_at
  FROM direct_messages m
  LEFT JOIN users u ON u.id = m.from_user_id
  LEFT JOIN direct_messages reply_msg ON reply_msg.id = m.reply_to_id
  LEFT JOIN users ru ON ru.id = reply_msg.from_user_id
`;
}

/** Входящие ЛС без отметки просмотра текущим пользователем. */
router.get('/unread-count', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const r = await client.query(
      `
      SELECT COUNT(*)::int AS count
      FROM direct_messages m
      WHERE m.to_user_id = $1
        AND m.from_user_id <> $1
        AND NOT EXISTS (
          SELECT 1 FROM user_blocks b
          WHERE (b.blocker_user_id = $1 AND b.blocked_user_id = m.from_user_id)
             OR (b.blocker_user_id = m.from_user_id AND b.blocked_user_id = $1)
        )
        AND NOT EXISTS (
          SELECT 1 FROM direct_message_views v
          WHERE v.message_id = m.id AND v.user_id = $1
        )
      `,
      [me],
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

/** Непрочитанные входящие ЛС, сгруппированные по отправителю (для списка чатов). */
router.get('/unread-by-peer', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    const r = await client.query(
      `
      SELECT m.from_user_id AS peer_id, COUNT(*)::int AS cnt
      FROM direct_messages m
      WHERE m.to_user_id = $1
        AND m.from_user_id <> $1
        AND NOT EXISTS (
          SELECT 1 FROM user_blocks b
          WHERE (b.blocker_user_id = $1 AND b.blocked_user_id = m.from_user_id)
             OR (b.blocker_user_id = m.from_user_id AND b.blocked_user_id = $1)
        )
        AND NOT EXISTS (
          SELECT 1 FROM direct_message_views v
          WHERE v.message_id = m.id AND v.user_id = $1
        )
      GROUP BY m.from_user_id
      `,
      [me],
    );
    const byPeer: Record<string, number> = {};
    for (const row of r.rows) {
      const id = row.peer_id as string;
      const cnt = row.cnt as number;
      byPeer[id] = cnt;
    }
    return res.json({ byPeer });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

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
      ${directMessageSelectWithView()}
      WHERE (m.from_user_id = $1 AND m.to_user_id = $2)
         OR (m.from_user_id = $2 AND m.to_user_id = $1)
      ORDER BY m.created_at ASC
      LIMIT 200
      `,
      [me, other],
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

// Текущий mute push-уведомлений от пользователя (для меню в личном чате)
router.get('/with/:userId/mute', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const other = req.params.userId as string;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!other) return res.status(400).json({ error: 'Invalid userId' });

  const client = await pool.connect();
  try {
    const r = await client.query(
      `
      SELECT muted_until
      FROM user_direct_chat_mutes
      WHERE user_id = $1 AND peer_user_id = $2
      `,
      [me, other],
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

// Установить/сбросить mute push-уведомлений от пользователя
router.post('/with/:userId/mute', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const other = req.params.userId as string;
  const { muted_until } = (req.body ?? {}) as { muted_until?: string | null };
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!other) return res.status(400).json({ error: 'Invalid userId' });

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
      INSERT INTO user_direct_chat_mutes (user_id, peer_user_id, muted_until, updated_at)
      VALUES ($1, $2, $3, now())
      ON CONFLICT (user_id, peer_user_id)
      DO UPDATE SET muted_until = EXCLUDED.muted_until, updated_at = now()
      `,
      [me, other, parsed],
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

// Удалить историю личного чата (обе стороны) для пары пользователей.
// Используется из меню личного чата.
router.delete('/with/:userId', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const other = req.params.userId as string;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!other) return res.status(400).json({ error: 'Invalid userId' });
  if (other === me) return res.status(400).json({ error: 'Invalid userId' });

  const client = await pool.connect();
  try {
    const del = await client.query(
      `
      DELETE FROM direct_messages
      WHERE (from_user_id = $1 AND to_user_id = $2)
         OR (from_user_id = $2 AND to_user_id = $1)
      `,
      [me, other],
    );
    // Сбросим локальный mute (на всякий случай, чтобы UI не зависел от "старого" состояния)
    await client.query(
      `DELETE FROM user_direct_chat_mutes WHERE user_id = $1 AND peer_user_id = $2`,
      [me, other],
    );
    return res.json({ success: true, deleted: del.rowCount ?? 0 });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Отметить чужие сообщения прочитанными (как в чате события)
router.post('/with/:userId/view', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const other = req.params.userId as string;
  const { up_to_id: upToId } = (req.body ?? {}) as { up_to_id?: string };

  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!other) return res.status(400).json({ error: 'Invalid userId' });
  if (!upToId || typeof upToId !== 'string') {
    return res.status(400).json({ error: 'up_to_id обязателен' });
  }

  const client = await pool.connect();
  try {
    if (await isBlockedEitherWay(client, me, other)) {
      return res.status(403).json({ error: 'Чат недоступен: блокировка' });
    }

    const anchor = await client.query(
      `
      SELECT id, created_at FROM direct_messages
      WHERE id = $1 AND (
        (from_user_id = $2 AND to_user_id = $3)
        OR (from_user_id = $3 AND to_user_id = $2)
      )
      `,
      [upToId, me, other],
    );
    if (anchor.rowCount === 0) {
      return res.status(404).json({ error: 'Message not found' });
    }
    const upToCreatedAt = anchor.rows[0].created_at as Date;

    await client.query(
      `
      INSERT INTO direct_message_views (message_id, user_id, viewed_at)
      SELECT m.id, $1, now()
      FROM direct_messages m
      WHERE (m.from_user_id = $1 AND m.to_user_id = $2 OR m.from_user_id = $2 AND m.to_user_id = $1)
        AND m.from_user_id <> $1
        AND (m.created_at <= $3 OR m.id = $4)
      ON CONFLICT (message_id, user_id)
      DO UPDATE SET viewed_at = EXCLUDED.viewed_at
      `,
      [me, other, upToCreatedAt, upToId],
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

// Отправить сообщение пользователю
router.post('/with/:userId', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const other = req.params.userId as string;
  const { text, reply_to_id } = req.body as { text?: string; reply_to_id?: string | null };
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!other) return res.status(400).json({ error: 'Invalid userId' });
  if (!text || typeof text !== 'string' || text.trim() === '') {
    return res.status(400).json({ error: 'Текст сообщения обязателен' });
  }
  if (other === me) return res.status(400).json({ error: 'Нельзя писать самому себе' });

  let replyToId: string | null = null;
  if (reply_to_id != null && reply_to_id !== '') {
    if (typeof reply_to_id !== 'string') {
      return res.status(400).json({ error: 'Некорректный reply_to_id' });
    }
    replyToId = reply_to_id;
  }

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

    if (replyToId) {
      const ok = await messageInConversation(client, replyToId, me, other);
      if (!ok) {
        return res.status(400).json({ error: 'Ответ на недопустимое сообщение' });
      }
    }

    const insert = await client.query(
      `
      INSERT INTO direct_messages (from_user_id, to_user_id, text, reply_to_id)
      VALUES ($1, $2, $3, $4)
      RETURNING id
      `,
      [me, other, encryptMessageText(text.trim()), replyToId],
    );
    const newId = insert.rows[0].id as string;

    const full = await client.query(
      `${directMessageSelectWithView()} WHERE m.id = $3`,
      [me, other, newId],
    );
    const row = full.rows[0] as Record<string, unknown>;
    (row as any).text = decryptMessageText((row as any).text);
    (row as any).reply_to_text = decryptMessageText((row as any).reply_to_text);
    const dn = String(row.user_display_name ?? '').trim();
    const em = String(row.user_email ?? '').trim();
    const senderLabel = dn || em || 'Сообщение';
    void notifyDirectMessage({
      recipientUserId: other,
      senderUserId: me,
      senderLabel,
      messageId: newId,
      text: text.trim(),
    });
    return res.status(201).json(full.rows[0]);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Изменить своё сообщение в ЛС
router.put('/with/:userId/:messageId', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const other = req.params.userId as string;
  const messageId = req.params.messageId as string;
  const { text } = req.body as { text?: string };
  if (!me) return res.status(401).json({ error: 'Unauthorized' });
  if (!text || typeof text !== 'string' || text.trim() === '') {
    return res.status(400).json({ error: 'Текст сообщения обязателен' });
  }

  const client = await pool.connect();
  try {
    if (await isBlockedEitherWay(client, me, other)) {
      return res.status(403).json({ error: 'Чат недоступен: блокировка' });
    }

    const upd = await client.query(
      `
      UPDATE direct_messages
      SET text = $1, edited_at = now()
      WHERE id = $2
        AND from_user_id = $3
        AND to_user_id = $4
      RETURNING id
      `,
      [encryptMessageText(text.trim()), messageId, me, other],
    );
    if (upd.rowCount === 0) {
      return res.status(404).json({ error: 'Сообщение не найдено или не ваше' });
    }

    const full = await client.query(
      `${directMessageSelectWithView()} WHERE m.id = $3`,
      [me, other, messageId],
    );
    const row = full.rows[0] as Record<string, unknown>;
    (row as any).text = decryptMessageText((row as any).text);
    (row as any).reply_to_text = decryptMessageText((row as any).reply_to_text);
    return res.json(row);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    return res.status(500).json({ error: 'Internal error' });
  } finally {
    client.release();
  }
});

// Удалить своё исходящее сообщение
router.delete('/with/:userId/:messageId', authMiddleware, async (req: AuthRequest, res) => {
  const me = req.user?.id;
  const other = req.params.userId as string;
  const messageId = req.params.messageId as string;
  if (!me) return res.status(401).json({ error: 'Unauthorized' });

  const client = await pool.connect();
  try {
    if (await isBlockedEitherWay(client, me, other)) {
      return res.status(403).json({ error: 'Чат недоступен: блокировка' });
    }

    const del = await client.query(
      `
      DELETE FROM direct_messages
      WHERE id = $1 AND from_user_id = $2 AND to_user_id = $3
      RETURNING id
      `,
      [messageId, me, other],
    );
    if (del.rowCount === 0) {
      return res.status(404).json({ error: 'Сообщение не найдено или не ваше' });
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

export default router;
