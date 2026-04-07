import crypto from 'crypto';

const PREFIX = 'enc:v1:';

let warnedNoKey = false;

function readKey(): Buffer | null {
  const raw = process.env.MESSAGE_ENCRYPTION_KEY;
  if (!raw || raw.trim() === '') return null;
  try {
    // Expect base64-encoded 32 bytes (AES-256)
    const buf = Buffer.from(raw.trim(), 'base64');
    if (buf.length !== 32) return null;
    return buf;
  } catch {
    return null;
  }
}

function warnOnceNoKey(): void {
  if (warnedNoKey) return;
  warnedNoKey = true;
  // eslint-disable-next-line no-console
  console.warn(
    'MESSAGE_ENCRYPTION_KEY is not set (or invalid). Message texts will be stored in plaintext.',
  );
}

export function encryptMessageText(plain: string): string {
  const t = plain ?? '';
  if (t.trim() === '') return t;
  if (t.startsWith(PREFIX)) return t; // already encrypted

  const key = readKey();
  if (!key) {
    warnOnceNoKey();
    return t;
  }

  const iv = crypto.randomBytes(12); // recommended for GCM
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([cipher.update(t, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();

  return `${PREFIX}${iv.toString('base64')}:${ciphertext.toString('base64')}:${tag.toString('base64')}`;
}

export function decryptMessageText(stored: unknown): string {
  const s = typeof stored === 'string' ? stored : stored == null ? '' : String(stored);
  if (!s.startsWith(PREFIX)) return s;

  const key = readKey();
  if (!key) {
    warnOnceNoKey();
    // Can't decrypt without key; return placeholder to avoid leaking ciphertext to UI
    return '';
  }

  try {
    const payload = s.slice(PREFIX.length);
    const [ivB64, ctB64, tagB64] = payload.split(':');
    if (!ivB64 || !ctB64 || !tagB64) return '';
    const iv = Buffer.from(ivB64, 'base64');
    const ct = Buffer.from(ctB64, 'base64');
    const tag = Buffer.from(tagB64, 'base64');

    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAuthTag(tag);
    const plain = Buffer.concat([decipher.update(ct), decipher.final()]).toString('utf8');
    return plain;
  } catch {
    return '';
  }
}

