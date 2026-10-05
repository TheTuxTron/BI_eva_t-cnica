import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeApp, login, bearer } from './helpers.js';
import { isValidCedula, buildCedula } from '../src/lib/cedula.js';

test('cédula ecuatoriana: algoritmo módulo 10', () => {
  assert.equal(isValidCedula('1710034065'), true);
  assert.equal(isValidCedula('1710034066'), false);
  assert.equal(isValidCedula('2510034065'), false); // provincia inválida
  assert.equal(isValidCedula(buildCedula('060412345')), true);
});

test('onboarding completo: registro → OTP → cuenta abierta con bono', async () => {
  const { api } = await makeApp();
  const reg = await api.post('/v1/auth/register').send({
    cedula: buildCedula('110456789'), firstName: 'Luis', lastName: 'Paredes', email: 'luis@test.ec',
    phone: '0987654321', birthDate: '1995-05-05', password: 'Segura123', acceptTerms: true,
  });
  assert.equal(reg.status, 201);
  assert.match(reg.body.devOtp, /^\d{6}$/);

  const bad = await api.post('/v1/auth/otp/verify').send({ userId: reg.body.userId, code: reg.body.devOtp === '000000' ? '111111' : '000000' });
  assert.equal(bad.body.error.code, 'OTP_INVALID');

  const ok = await api.post('/v1/auth/otp/verify').send({ userId: reg.body.userId, code: reg.body.devOtp });
  assert.equal(ok.status, 201);
  const accounts = await api.get('/v1/accounts').set(bearer(ok.body.accessToken));
  assert.equal(accounts.body.items.length, 1);
  assert.equal(accounts.body.totalCents, 1000);
});

test('registro valida cédula, mayoría de edad y contraseña', async () => {
  const { api } = await makeApp();
  const res = await api.post('/v1/auth/register').send({ cedula: '1234567890', firstName: 'A', lastName: 'B', email: 'x', phone: '1', birthDate: '2015-01-01', password: 'abc', acceptTerms: false });
  assert.equal(res.status, 400);
  const fields = res.body.error.details.map((d) => d.field);
  for (const f of ['cedula', 'email', 'phone', 'password', 'acceptTerms']) assert.ok(fields.includes(f), f);
});

test('login inválido devuelve 401 sin revelar si el usuario existe', async () => {
  const { api } = await makeApp();
  const r1 = await api.post('/v1/auth/login').send({ username: 'ana@kinti.ec', password: 'mala' });
  const r2 = await api.post('/v1/auth/login').send({ username: 'nadie@kinti.ec', password: 'mala' });
  assert.equal(r1.status, 401);
  assert.equal(r1.body.error.message, r2.body.error.message);
});

test('refresh rota tokens y detecta reúso (revoca la familia)', async () => {
  const { api } = await makeApp();
  const s = await login(api);
  const r1 = await api.post('/v1/auth/refresh').send({ refreshToken: s.refreshToken });
  assert.equal(r1.status, 200);
  assert.notEqual(r1.body.refreshToken, s.refreshToken);
  const reuse = await api.post('/v1/auth/refresh').send({ refreshToken: s.refreshToken });
  assert.equal(reuse.status, 401);
  const afterReuse = await api.post('/v1/auth/refresh').send({ refreshToken: r1.body.refreshToken });
  assert.equal(afterReuse.status, 401, 'el token nuevo también queda revocado');
});

test('rutas protegidas exigen token', async () => {
  const { api } = await makeApp();
  const r = await api.get('/v1/accounts');
  assert.equal(r.status, 401);
  assert.ok(r.body.error.requestId);
});
