import fs from 'fs';
import path from 'path';

import admin from 'firebase-admin';
import { pool } from '../db';

function resolveServiceAccountFilePath(p: string): string {
  const t = p.trim();
  if (path.isAbsolute(t)) return t;
  return path.join(process.cwd(), t);
}

const TEXT_PREVIEW_MAX = 140;

function truncateText(s: string, max: number): string {
  const t = s.trim();
  if (t.length <= max) return t;
  return `${t.slice(0, max - 1)}…`;
}

function isPushEnabled(): boolean {
  return admin.apps.length > 0;
}

/** Вызвать один раз при старте сервера. Без credentials push отключён. */
export function initFirebaseAdmin(): void {
  if (admin.apps.length > 0) return;
  try {
    const fromPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    if (fromPath && fromPath.trim() !== '') {
      const resolved = resolveServiceAccountFilePath(fromPath);
      if (fs.existsSync(resolved)) {
        const raw = fs.readFileSync(resolved, 'utf8');
        const cred = JSON.parse(raw) as admin.ServiceAccount;
        admin.initializeApp({ credential: admin.credential.cert(cred) });
        // eslint-disable-next-line no-console
        console.log('Firebase Admin: initialized (FIREBASE_SERVICE_ACCOUNT_PATH)');
        return;
      }
      // eslint-disable-next-line no-console
      console.warn(`Firebase: file not found: ${resolved}`);
    }

    const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (json && json.trim() !== '') {
      const cred = JSON.parse(json) as admin.ServiceAccount;
      admin.initializeApp({ credential: admin.credential.cert(cred) });
      // eslint-disable-next-line no-console
      console.log('Firebase Admin: initialized (FIREBASE_SERVICE_ACCOUNT_JSON)');
      return;
    }
    if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      admin.initializeApp({ credential: admin.credential.applicationDefault() });
      // eslint-disable-next-line no-console
      console.log('Firebase Admin: initialized (GOOGLE_APPLICATION_CREDENTIALS)');
      return;
    }
    // eslint-disable-next-line no-console
    console.warn(
      'Firebase push disabled: set FIREBASE_SERVICE_ACCOUNT_PATH, FIREBASE_SERVICE_ACCOUNT_JSON, or GOOGLE_APPLICATION_CREDENTIALS (see backend/.env.example)',
    );
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('Firebase Admin init failed:', e);
  }
}

async function fetchTokensForUser(userId: string): Promise<string[]> {
  const r = await pool.query(`SELECT token FROM user_push_tokens WHERE user_id = $1`, [userId]);
  return r.rows.map((row) => row.token as string);
}

async function removeInvalidTokens(invalid: string[]): Promise<void> {
  if (invalid.length === 0) return;
  await pool.query(`DELETE FROM user_push_tokens WHERE token = ANY($1::text[])`, [invalid]);
}

async function sendToTokens(
  tokens: string[],
  notification: { title: string; body: string },
  data: Record<string, string>,
): Promise<void> {
  if (!isPushEnabled() || tokens.length === 0) return;

  const messaging = admin.messaging();
  const res = await messaging.sendEachForMulticast({
    tokens,
    notification,
    data,
    android: { priority: 'high' },
    apns: {
      payload: {
        aps: { sound: 'default', badge: 1 },
      },
    },
  });

  const toRemove: string[] = [];
  res.responses.forEach((r, i) => {
    if (!r.success && r.error) {
      const code = r.error.code;
      if (
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/unregistered'
      ) {
        const tok = tokens[i];
        if (tok) toRemove.push(tok);
      }
    }
  });
  await removeInvalidTokens(toRemove);
}

export async function notifyDirectMessage(params: {
  recipientUserId: string;
  senderUserId: string;
  senderLabel: string;
  messageId: string;
  text: string;
}): Promise<void> {
  const { recipientUserId, senderUserId, senderLabel, messageId, text } = params;
  const tokens = await fetchTokensForUser(recipientUserId);
  if (tokens.length === 0) return;

  const title = senderLabel || 'Новое сообщение';
  const body = truncateText(text, TEXT_PREVIEW_MAX);
  await sendToTokens(tokens, { title, body }, {
    type: 'direct',
    peer_id: senderUserId,
    message_id: messageId,
    sender_name: senderLabel,
  });
}

export async function notifyEventChatMessage(params: {
  eventId: string;
  eventTitle: string;
  messageId: string;
  senderUserId: string;
  senderLabel: string;
  text: string;
}): Promise<void> {
  const { eventId, eventTitle, messageId, senderUserId, senderLabel, text } = params;

  const r = await pool.query(
    `
    SELECT user_id FROM event_rsvp
    WHERE event_id = $1 AND status = 1 AND user_id <> $2
    `,
    [eventId, senderUserId],
  );

  if (r.rows.length === 0) return;

  const title = eventTitle || 'Чат события';
  const subtitle = senderLabel || 'Участник';
  const body = truncateText(text, TEXT_PREVIEW_MAX);
  const notificationBody = `${subtitle}: ${body}`;

  for (const row of r.rows) {
    const uid = row.user_id as string;
    const tokens = await fetchTokensForUser(uid);
    if (tokens.length === 0) continue;
    await sendToTokens(
      tokens,
      { title, body: notificationBody },
      {
        type: 'event',
        event_id: eventId,
        message_id: messageId,
        sender_name: senderLabel,
      },
    );
  }
}
