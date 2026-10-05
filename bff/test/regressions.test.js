import { test } from 'node:test';
import assert from 'node:assert/strict';
import jwt from 'jsonwebtoken';
import { makeApp, login, bearer } from './helpers.js';
import { buildCedula } from '../src/lib/cedula.js';

test('regresión: la URL de la micro-app usa el host desde el que llega la app (emulador/celular)', async () => {
  const { api } = await makeApp({ config: { publicBaseUrl: '' } });
  const t = (await login(api)).accessToken;
  const fromEmulator = await api.post('/v1/microapps/simulador-credito/session').set(bearer(t)).set('Host', '10.0.2.2:8080');
  assert.equal(fromEmulator.body.url, 'http://10.0.2.2:8080/microapps/simulador-credito/index.html');
  const fromPhone = await api.post('/v1/microapps/simulador-credito/session').set(bearer(t)).set('Host', '192.168.1.50:8080');
  assert.match(fromPhone.body.url, /^http:\/\/192\.168\.1\.50:8080\//);
  // Detrás de un proxy HTTPS (Render) respeta X-Forwarded-Proto.
  const behindProxy = await api.post('/v1/microapps/simulador-credito/session').set(bearer(t)).set('Host', 'kinti.onrender.com').set('X-Forwarded-Proto', 'https');
  assert.match(behindProxy.body.url, /^https:\/\/kinti\.onrender\.com\//);
});

test('regresión: PUBLIC_BASE_URL configurada tiene prioridad', async () => {
  const { api } = await makeApp({ config: { publicBaseUrl: 'https://cdn.kinti.ec' } });
  const t = (await login(api)).accessToken;
  const r = await api.post('/v1/microapps/simulador-credito/session').set(bearer(t)).set('Host', '10.0.2.2:8080');
  assert.match(r.body.url, /^https:\/\/cdn\.kinti\.ec\//);
});

test('regresión: token válido de un usuario inexistente → 401 (no 500)', async () => {
  const { api, deps } = await makeApp();
  const ghost = jwt.sign({ sub: 'usr_borrado', typ: 'access' }, deps.config.jwtSecret, { issuer: 'kinti-bff', audience: 'kinti-app', expiresIn: 60 });
  for (const path of ['/v1/me', '/v1/experience/home']) {
    const r = await api.get(path).set(bearer(ghost));
    assert.equal(r.status, 401, path);
  }
});

test('recorrido completo de un cliente nuevo: todas las pantallas responden', async () => {
  const fx = async () => ({ ok: true, json: async () => ({ base: 'USD', date: '2026-10-02', rates: { EUR: 0.86, COP: 3900, PEN: 3.4 } }) });
  const { api } = await makeApp({ fetchImpl: fx, config: { publicBaseUrl: '' } });
  const reg = await api.post('/v1/auth/register').send({
    cedula: buildCedula('060987654'), firstName: 'Lucía', lastName: 'Pérez', email: 'lucia.perez@kinti.ec',
    phone: '0987001122', birthDate: '2000-02-29', password: 'Segura2026', acceptTerms: true,
  });
  assert.equal(reg.status, 201, JSON.stringify(reg.body));
  const ver = await api.post('/v1/auth/otp/verify').send({ userId: reg.body.userId, code: reg.body.devOtp });
  assert.equal(ver.status, 201);
  const t = ver.body.accessToken;
  for (const path of ['/v1/me', '/v1/accounts', '/v1/experience/home', '/v1/notifications', '/v1/insights', '/v1/fx/rates', '/v1/microapps', '/v1/config']) {
    const r = await api.get(path).set(bearer(t)).set('Host', '10.0.2.2:8080');
    assert.equal(r.status, 200, `${path} → ${r.status} ${JSON.stringify(r.body)}`);
  }
  const s = await api.post('/v1/microapps/simulador-credito/session').set(bearer(t)).set('Host', '10.0.2.2:8080');
  const sim = await api.post('/v1/microapp-api/simulador-credito/simulate').set(bearer(s.body.token)).send({ mode: 'ahorro', amount: '50', months: 12 });
  assert.equal(sim.status, 200);
  assert.ok(sim.body.finalCents > 60000);
  const a = await api.post('/v1/assistant/messages').set(bearer(t)).send({ message: '¿Cuál es mi saldo?' });
  assert.match(a.body.reply, /\$10,00/);
  const page = await api.get('/microapps/simulador-credito/index.html');
  assert.equal(page.status, 200);
});
