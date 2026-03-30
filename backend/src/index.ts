import http from 'http';
import express from 'express';
import cors from 'cors';
import { Server as SocketIOServer } from 'socket.io';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { pool, testConnection } from './db';
import authRouter from './routes/auth';
import eventsRouter from './routes/events';
import blocksRouter from './routes/blocks';
import friendsRouter from './routes/friends';
import usersRouter from './routes/users';
import messagesRouter from './routes/messages';

dotenv.config();

const PORT = Number(process.env.PORT || 4000);

const app = express();
app.use(cors());
app.use(express.json());

// Static uploads (avatars, etc.)
const uploadsDir = path.join(process.cwd(), 'uploads');
try {
  fs.mkdirSync(uploadsDir, { recursive: true });
} catch {
  // ignore
}
app.use('/uploads', express.static(uploadsDir));

app.get('/health', async (_req, res) => {
  try {
    await testConnection();
    res.json({ ok: true });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(err);
    res.status(500).json({ ok: false });
  }
});

app.use('/auth', authRouter);
app.use('/events', eventsRouter);
app.use('/blocks', blocksRouter);
app.use('/friends', friendsRouter);
app.use('/users', usersRouter);
app.use('/messages', messagesRouter);

// Always return JSON errors to the mobile app.
// Otherwise Express default 404/500 responses are HTML and the client fails with FormatException.
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.use((err: unknown, _req: any, res: any, _next: any) => {
  const message =
    err instanceof Error
      ? err.message
      : typeof err === 'string'
        ? err
        : 'Internal error';
  // eslint-disable-next-line no-console
  console.error(err);
  res.status(500).json({ error: message });
});

const server = http.createServer(app);

const io = new SocketIOServer(server, {
  cors: {
    origin: '*',
  },
});
app.set('io', io);

io.on('connection', (socket) => {
  socket.on('joinEvent', (eventId: string) => {
    socket.join(`event:${eventId}`);
  });

  socket.on('leaveEvent', (eventId: string) => {
    socket.leave(`event:${eventId}`);
  });

  socket.on(
    'sendMessage',
    async (payload: { eventId: string; userId: string; text: string }) => {
      const { eventId, userId, text } = payload;
      if (!eventId || !userId || !text.trim()) return;

      const client = await pool.connect();
      try {
        const participant = await client.query(
          'SELECT 1 FROM event_rsvp WHERE event_id = $1 AND user_id = $2 AND status = 1',
          [eventId, userId],
        );
        if (participant.rowCount === 0) return;

        const insert = await client.query(
          `
          INSERT INTO event_messages (event_id, user_id, text)
          VALUES ($1, $2, $3)
          RETURNING id, event_id, user_id, text, created_at, edited_at
          `,
          [eventId, userId, text.trim()],
        );

        const msg = insert.rows[0];
        io.to(`event:${eventId}`).emit('newMessage', msg);
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error(err);
      } finally {
        client.release();
      }
    },
  );
});

server.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`Backend listening on http://localhost:${PORT}`);
});

