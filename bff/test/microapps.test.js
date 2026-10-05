import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeApp, login, bearer } from './helpers.js';

test('micro-app: sesión con token de alcance limitado y simulación real', async () => {
  const { api } = await makeApp();
  const t = (await login(api, 'carlos@kinti.ec')).accessToken;
  const cat = await api.get('/v1/microapps').set(bearer(t));
  assert.equal(cat.body.items[0].id, 'simulador-credito');
  const s = await api.post('/v1/microapps/simulador-credito/session').set(bearer(t));
  assert.ok(s.body.token);
  // El token de micro-app NO sirve para la API principal.
  assert.equal((await api.get('/v1/accounts').set(bearer(s.body.token))).status, 401);
  // Y el access token principal NO sirve para la API de la micro-app.
  assert.equal((await api.post('/v1/microapp-api/simulador-credito/simulate').set(bearer(t)).send({ amount: 1000, months: 12 })).status, 401);
  const sim = await api.post('/v1/microapp-api/simulador-credito/simulate').set(bearer(s.body.token)).send({ mode: 'credito', amount: '10000', months: 12 });
  assert.equal(sim.status, 200);
  assert.equal(sim.body.segment, 'premium');
  assert.equal(sim.body.schedule.length, 12);
  assert.equal(sim.body.schedule.at(-1).balanceCents, 0);
  assert.ok(Math.abs(sim.body.paymentCents - 88613) < 5); // 10.000 a 12 meses al 11,5%
});

test('micro-app estática se sirve desde el BFF', async () => {
  const { api } = await makeApp();
  const r = await api.get('/microapps/simulador-credito/index.html');
  assert.equal(r.status, 200);
  assert.match(r.text, /kintiReceive/);
});
