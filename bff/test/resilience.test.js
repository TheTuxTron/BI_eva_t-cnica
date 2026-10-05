import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeApp, login, bearer } from './helpers.js';
import { CircuitBreaker } from '../src/services/circuitBreaker.js';

const okFx = async () => ({ ok: true, json: async () => ({ base: 'USD', date: '2026-10-02', rates: { EUR: 0.91, COP: 4100 } }) });
const failFx = async () => { throw new Error('ECONNRESET'); };

test('fx: datos reales en caché y stale ante caída del tercero', async () => {
  let impl = okFx;
  const { api, deps } = await makeApp({ fetchImpl: (...a) => impl(...a), config: { fxTtlSec: 0 } });
  const t = (await login(api)).accessToken;
  const r1 = await api.get('/v1/fx/rates').set(bearer(t));
  assert.equal(r1.body.stale, false);
  impl = failFx;
  const r2 = await api.get('/v1/fx/rates').set(bearer(t));
  assert.equal(r2.status, 200);
  assert.equal(r2.body.stale, true);
  assert.equal(r2.body.rates.EUR, 0.91);
  await api.get('/v1/fx/rates').set(bearer(t));
  await api.get('/v1/fx/rates').set(bearer(t));
  assert.equal(deps.fx.breaker.state, 'open');
});

test('fx: 503 si el tercero cae y no hay caché', async () => {
  const { api } = await makeApp({ fetchImpl: failFx });
  const token = (await login(api)).accessToken;
  const r = await api.get('/v1/fx/rates').set(bearer(token));
  assert.equal(r.status, 503);
  assert.equal(r.body.error.code, 'DEPENDENCY_UNAVAILABLE');
});

test('circuit breaker pasa a half-open tras el timeout', () => {
  let now = 0;
  const cb = new CircuitBreaker({ failureThreshold: 2, resetTimeoutMs: 1000, now: () => now });
  cb.onFailure(); cb.onFailure();
  assert.equal(cb.canRequest(), false);
  now = 1500;
  assert.equal(cb.canRequest(), true);
  assert.equal(cb.state, 'half-open');
});

test('caos: caída parcial de un dominio no afecta a los demás', async () => {
  const { api } = await makeApp({ chaosDeps: { sleep: async () => {} } });
  const t = (await login(api)).accessToken;
  await api.put('/v1/admin/chaos').set('X-Admin-Key', 'dev-admin-key').send({ enabled: true, outages: ['experience'] });
  const exp = await api.get('/v1/experience/home').set(bearer(t));
  assert.equal(exp.status, 503);
  assert.equal(exp.headers['retry-after'], '10');
  const acc = await api.get('/v1/accounts').set(bearer(t));
  assert.equal(acc.status, 200);
});

test('caos: errores intermitentes según errorRate y admin protegido', async () => {
  const { api } = await makeApp({ chaosDeps: { sleep: async () => {}, random: () => 0.1 } });
  const t = (await login(api)).accessToken;
  const denied = await api.put('/v1/admin/chaos').send({ enabled: true });
  assert.equal(denied.status, 403);
  await api.put('/v1/admin/chaos').set('X-Admin-Key', 'dev-admin-key').send({ enabled: true, errorRate: 0.5, groups: ['accounts'] });
  assert.equal((await api.get('/v1/accounts').set(bearer(t))).body.error.code, 'TRANSIENT_FAILURE');
  assert.equal((await api.get('/v1/notifications').set(bearer(t))).status, 200);
});
