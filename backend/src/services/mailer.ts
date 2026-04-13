import nodemailer from 'nodemailer';

function env(name: string): string | undefined {
  const v = process.env[name];
  if (!v) return undefined;
  const t = v.trim();
  return t === '' ? undefined : t;
}

export function isMailerEnabled(): boolean {
  return Boolean(
    env('MAIL_HOST') &&
      env('MAIL_PORT') &&
      env('MAIL_USERNAME') &&
      env('MAIL_PASSWORD') &&
      env('MAIL_FROM_ADDRESS'),
  );
}

export function getPublicBackendBaseUrl(): string {
  const raw = env('PUBLIC_BACKEND_URL');
  if (raw) return raw.replace(/\/+$/, '');
  return 'http://localhost:4006';
}

export async function sendEmail(params: {
  to: string;
  subject: string;
  text: string;
  html?: string;
}): Promise<void> {
  if (!isMailerEnabled()) return;

  const transporter = nodemailer.createTransport({
    host: env('MAIL_HOST'),
    port: Number(env('MAIL_PORT') ?? 587),
    secure: false,
    auth: {
      user: env('MAIL_USERNAME'),
      pass: env('MAIL_PASSWORD'),
    },
    requireTLS: (env('MAIL_ENCRYPTION') ?? '').toLowerCase() === 'tls',
  });

  const fromName = env('MAIL_FROM_NAME') ?? 'EventApp';
  const fromAddress = env('MAIL_FROM_ADDRESS')!;
  const from = `${fromName} <${fromAddress}>`;

  await transporter.sendMail({
    from,
    to: params.to,
    subject: params.subject,
    text: params.text,
    html: params.html,
  });
}

