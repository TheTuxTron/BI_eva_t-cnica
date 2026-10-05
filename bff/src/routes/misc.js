import { Router } from 'express';
import { z } from 'zod';
import { asyncH, parse, HttpError, notFound } from '../lib/errors.js';
import { userContext } from '../services/users.js';
import { computeInsights } from '../services/insights.js';
import { defaultChaos, GROUPS } from '../middleware/chaos.js';
import { newId } from '../lib/crypto.js';

export function fxRoutes({ fx }) {
  const r = Router();
  r.get('/rates', asyncH(async (_req, res) => {
    try {
      res.json(await fx.getRates());
    } catch (e) {
      if (e.unavailable) throw new HttpError(503, 'DEPENDENCY_UNAVAILABLE', 'El servicio de tipo de cambio no está disponible');
      throw e;
    }
  }));
  return r;
}

export function assistantRoutes({ db, assistant }) {
  const r = Router();
  r.post('/messages', asyncH(async (req, res) => {
    const { message } = parse(z.object({ message: z.string().trim().min(1).max(500) }), req.body);
    const ctx = userContext(db, req.userId);
    const { summary } = computeInsights(db, req.userId);
    const answer = await assistant.answer(message, { totalBalanceCents: ctx.totalBalanceCents, accounts: ctx.accounts.length, ...summary });
    res.json(answer);
  }));
  return r;
}

const chaosSchema = z.object({
  enabled: z.boolean().optional(),
  latencyMs: z.number().int().min(0).max(30_000).optional(),
  jitterMs: z.number().int().min(0).max(10_000).optional(),
  errorRate: z.number().min(0).max(1).optional(),
  groups: z.array(z.enum(Object.keys(GROUPS))).optional(),
  outages: z.array(z.enum(Object.keys(GROUPS))).optional(),
});

const campaignSchema = z.object({
  title: z.string().min(3).max(80), body: z.string().min(3).max(200),
  ctaLabel: z.string().max(30).optional(), ctaDeeplink: z.string().max(200).optional(),
  style: z.enum(['accent', 'info', 'premium']).default('accent'),
  segments: z.array(z.enum(['joven', 'clasico', 'premium'])).default([]),
  priority: z.number().int().default(50), startsAt: z.string().optional(), endsAt: z.string().optional(),
});

/** Backoffice mínimo: caos, campañas, flags y push de prueba. Protegido con X-Admin-Key. */
export function adminRoutes({ db, state, push }) {
  const r = Router();
  r.get('/chaos', (_req, res) => res.json(state.chaos));
  r.put('/chaos', (req, res) => { state.chaos = { ...state.chaos, ...parse(chaosSchema, req.body) }; res.json(state.chaos); });
  r.delete('/chaos', (_req, res) => { state.chaos = defaultChaos(); res.json(state.chaos); });

  r.get('/flags', (_req, res) => res.json(state.flags));
  r.put('/flags', (req, res) => { state.flags = { ...state.flags, ...parse(z.record(z.boolean()), req.body) }; res.json(state.flags); });

  r.get('/campaigns', (_req, res) => res.json(db.prepare('SELECT * FROM campaigns ORDER BY priority DESC').all()));
  r.post('/campaigns', (req, res) => {
    const c = parse(campaignSchema, req.body);
    const id = newId('cmp');
    db.prepare(`INSERT INTO campaigns (id,title,body,cta_label,cta_deeplink,style,segments,priority,active,starts_at,ends_at,created_at)
      VALUES (?,?,?,?,?,?,?,?,1,?,?,?)`).run(id, c.title, c.body, c.ctaLabel ?? null, c.ctaDeeplink ?? null, c.style, JSON.stringify(c.segments), c.priority, c.startsAt ?? null, c.endsAt ?? null, new Date().toISOString());
    res.status(201).json(db.prepare('SELECT * FROM campaigns WHERE id = ?').get(id));
  });
  r.patch('/campaigns/:id', (req, res) => {
    const { active } = parse(z.object({ active: z.boolean() }), req.body);
    const info = db.prepare('UPDATE campaigns SET active = ? WHERE id = ?').run(active ? 1 : 0, req.params.id);
    if (!info.changes) throw notFound();
    res.json(db.prepare('SELECT * FROM campaigns WHERE id = ?').get(req.params.id));
  });

  r.post('/notifications', asyncH(async (req, res) => {
    const { email, title, body, deeplink } = parse(z.object({ email: z.string().email(), title: z.string().min(1), body: z.string().min(1), deeplink: z.string().optional() }), req.body);
    const u = db.prepare('SELECT id FROM users WHERE email = ?').get(email.toLowerCase());
    if (!u) throw notFound('Usuario no encontrado');
    res.status(201).json(await push.notify(u.id, { title, body, deeplink }));
  }));
  return r;
}

export function healthRoutes({ db, fx }) {
  const r = Router();
  r.get('/live', (_req, res) => res.json({ status: 'ok' }));
  r.get('/ready', (_req, res) => {
    try {
      db.prepare('SELECT 1').get();
      res.json({ status: 'ok', dependencies: { db: 'ok', fx: fx.breaker.state } });
    } catch {
      res.status(503).json({ status: 'degraded', dependencies: { db: 'down' } });
    }
  });
  return r;
}
