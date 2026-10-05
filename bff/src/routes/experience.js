import { Router } from 'express';
import { z } from 'zod';
import { asyncH, parse } from '../lib/errors.js';
import { userContext, publicUser, DEFAULT_PREFS } from '../services/users.js';
import { buildHomeExperience, eventCountsFor, SDUI_SCHEMA_VERSION } from '../services/personalization.js';
import { computeInsights } from '../services/insights.js';

export const DEFAULT_FLAGS = { assistant: true, fx: true, insights: true, microapps: true, transfers: true };

const prefsSchema = z.object({
  theme: z.enum(['system', 'light', 'dark']).optional(),
  hiddenSections: z.array(z.string().max(60)).max(20).optional(),
  notificationsEnabled: z.boolean().optional(),
  balanceVisible: z.boolean().optional(),
}).strict();

const eventsSchema = z.object({
  events: z.array(z.object({ name: z.string().regex(/^[a-z0-9_]{2,60}$/), at: z.string().optional(), props: z.record(z.any()).optional() })).min(1).max(50),
});

export function meRoutes({ db, metrics }) {
  const r = Router();
  r.get('/', asyncH(async (req, res) => {
    const ctx = userContext(db, req.userId);
    res.json({ ...publicUser(ctx.user), segment: ctx.segment, preferences: ctx.prefs });
  }));
  r.put('/preferences', asyncH(async (req, res) => {
    const patch = parse(prefsSchema, req.body);
    const current = userContext(db, req.userId).prefs;
    const next = { ...DEFAULT_PREFS, ...current, ...patch };
    db.prepare('INSERT INTO preferences (user_id,json) VALUES (?,?) ON CONFLICT(user_id) DO UPDATE SET json = excluded.json').run(req.userId, JSON.stringify(next));
    res.json(next);
  }));
  // Señales de comportamiento (batch) que alimentan la personalización y las métricas de UX.
  r.post('/events', asyncH(async (req, res) => {
    const { events } = parse(eventsSchema, req.body);
    const ins = db.prepare('INSERT INTO events (user_id,name,created_at) VALUES (?,?,?)');
    for (const e of events) {
      ins.run(req.userId, e.name, e.at ?? new Date().toISOString());
      metrics.clientEvents.inc({ name: e.name });
    }
    res.status(202).json({ accepted: events.length });
  }));
  return r;
}

export function experienceRoutes({ db, state }) {
  const r = Router();
  r.get('/home', asyncH(async (req, res) => {
    const ctx = userContext(db, req.userId);
    const { insights } = computeInsights(db, req.userId);
    const campaigns = db.prepare('SELECT * FROM campaigns').all();
    const exp = buildHomeExperience({ ctx, eventCounts: eventCountsFor(db, req.userId), campaigns, insights, flags: state.flags });
    res.setHeader('Cache-Control', 'private, max-age=0');
    res.json(exp);
  }));
  return r;
}

/** Config remota: feature flags + versión mínima soportada (kill-switch sin publicar app). */
export function configRoutes({ state }) {
  const r = Router();
  r.get('/', (_req, res) => {
    res.json({ flags: state.flags, minSupportedVersion: '1.0.0', sduiSchemaVersion: SDUI_SCHEMA_VERSION, pollingIntervalSec: 30 });
  });
  return r;
}

export function insightsRoutes({ db }) {
  const r = Router();
  r.get('/', asyncH(async (req, res) => res.json(computeInsights(db, req.userId))));
  return r;
}
