import pino from 'pino';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { openDb } from '../src/db.js';

export async function makeApp({ fetchImpl, chaosDeps, config = {} } = {}) {
  const cfg = loadConfig({ env: 'test', dbPath: ':memory:', exposeOtp: true, ...config });
  const { app, deps } = await createApp({ config: cfg, logger: pino({ level: 'silent' }), db: openDb(':memory:'), fetchImpl, chaosDeps });
  return { app, deps, api: request(app) };
}

export async function login(api, username = 'ana@kinti.ec') {
  const res = await api.post('/v1/auth/login').send({ username, password: 'Kinti2026!' });
  if (res.status !== 200) throw new Error(`login failed ${res.status}`);
  return res.body;
}

export const bearer = (t) => ({ Authorization: `Bearer ${t}` });
