import { Router } from 'express';
import { z } from 'zod';
import { asyncH, parse, notFound } from '../lib/errors.js';

export function notificationsRoutes({ db }) {
  const r = Router();
  r.get('/', asyncH(async (req, res) => {
    const since = req.query.since ? String(req.query.since) : '0000';
    const items = db.prepare('SELECT * FROM notifications WHERE user_id = ? AND created_at > ? ORDER BY created_at DESC LIMIT 50').all(req.userId, since)
      .map((n) => ({ id: n.id, title: n.title, body: n.body, deeplink: n.deeplink, createdAt: n.created_at, read: Boolean(n.read_at) }));
    const { unread } = db.prepare('SELECT COUNT(*) AS unread FROM notifications WHERE user_id = ? AND read_at IS NULL').get(req.userId);
    res.json({ items, unread });
  }));
  r.post('/:id/read', asyncH(async (req, res) => {
    const info = db.prepare('UPDATE notifications SET read_at = ? WHERE id = ? AND user_id = ? AND read_at IS NULL').run(new Date().toISOString(), req.params.id, req.userId);
    if (info.changes === 0 && !db.prepare('SELECT 1 FROM notifications WHERE id = ? AND user_id = ?').get(req.params.id, req.userId)) throw notFound();
    res.status(204).end();
  }));
  r.post('/read-all', asyncH(async (req, res) => {
    db.prepare('UPDATE notifications SET read_at = ? WHERE user_id = ? AND read_at IS NULL').run(new Date().toISOString(), req.userId);
    res.status(204).end();
  }));
  return r;
}

export function devicesRoutes({ db, push }) {
  const r = Router();
  r.post('/', asyncH(async (req, res) => {
    const { token, platform } = parse(z.object({ token: z.string().min(10).max(4096), platform: z.enum(['android', 'ios', 'web']) }), req.body);
    db.prepare('INSERT INTO devices (token,user_id,platform,updated_at) VALUES (?,?,?,?) ON CONFLICT(token) DO UPDATE SET user_id = excluded.user_id, updated_at = excluded.updated_at')
      .run(token, req.userId, platform, new Date().toISOString());
    res.status(201).json({ registered: true, fcmEnabled: push.fcmEnabled() });
  }));
  r.delete('/:token', asyncH(async (req, res) => {
    db.prepare('DELETE FROM devices WHERE token = ? AND user_id = ?').run(req.params.token, req.userId);
    res.status(204).end();
  }));
  return r;
}
