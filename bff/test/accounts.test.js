import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { makeApp, login, bearer } from './helpers.js';

test('movimientos paginados por cursor sin duplicados', async () => {
  const { api } = await makeApp();
  const { accessToken } = await login(api);
  const accs = await api.get('/v1/accounts').set(bearer(accessToken));
  const id = accs.body.items[0].id;
  const seen = new Set();
  let cursor = null; let pages = 0;
  do {
    const r = await api.get(`/v1/accounts/${id}/movements`).query({ limit: 10, ...(cursor ? { cursor } : {}) }).set(bearer(accessToken));
    assert.equal(r.status, 200);
    for (const m of r.body.items) { assert.ok(!seen.has(m.id)); seen.add(m.id); }
    cursor = r.body.nextCursor; pages++;
  } while (cursor && pages < 20);
  assert.ok(seen.size > 30);
});

test('no se puede leer la cuenta de otro cliente', async () => {
  const { api } = await makeApp();
  const { accessToken } = await login(api, 'ana@kinti.ec');
  const r = await api.get('/v1/accounts/acc_carlos_1').set(bearer(accessToken));
  assert.equal(r.status, 404);
});

test('transferencia idempotente: el reintento no debita dos veces', async () => {
  const { api } = await makeApp();
  const { accessToken } = await login(api, 'ana@kinti.ec');
  const before = (await api.get('/v1/accounts').set(bearer(accessToken))).body.items[0];
  const key = randomUUID();
  const body = { fromAccountId: before.id, toAccountNumber: '2200990011', amount: '12.50', description: 'Almuerzo' };
  const r1 = await api.post('/v1/transfers').set(bearer(accessToken)).set('Idempotency-Key', key).send(body);
  assert.equal(r1.status, 201);
  const r2 = await api.post('/v1/transfers').set(bearer(accessToken)).set('Idempotency-Key', key).send(body);
  assert.equal(r2.status, 201);
  assert.equal(r2.headers['idempotent-replayed'], 'true');
  assert.equal(r2.body.id, r1.body.id);
  const after = (await api.get('/v1/accounts').set(bearer(accessToken))).body.items[0];
  assert.equal(before.balanceCents - after.balanceCents, 1250);

  const mismatch = await api.post('/v1/transfers').set(bearer(accessToken)).set('Idempotency-Key', key).send({ ...body, amount: '99' });
  assert.equal(mismatch.status, 409);
});

test('transferencia valida fondos y genera notificación al destinatario', async () => {
  const { api } = await makeApp();
  const ana = await login(api, 'ana@kinti.ec');
  const acc = (await api.get('/v1/accounts').set(bearer(ana.accessToken))).body.items[0];
  const nsf = await api.post('/v1/transfers').set(bearer(ana.accessToken)).set('Idempotency-Key', randomUUID())
    .send({ fromAccountId: acc.id, toAccountNumber: '2200990011', amount: '999999' });
  assert.equal(nsf.status, 422);
  assert.equal(nsf.body.error.code, 'INSUFFICIENT_FUNDS');

  await api.post('/v1/transfers').set(bearer(ana.accessToken)).set('Idempotency-Key', randomUUID())
    .send({ fromAccountId: acc.id, toAccountNumber: '2200990011', amount: '5' });
  const maria = await login(api, 'maria@kinti.ec');
  const n = await api.get('/v1/notifications').set(bearer(maria.accessToken));
  assert.ok(n.body.items.some((i) => i.title === 'Recibiste dinero'));
  assert.ok(n.body.unread >= 1);
});

test('lookup de destinatario enmascara el titular', async () => {
  const { api } = await makeApp();
  const { accessToken } = await login(api);
  const r = await api.get('/v1/accounts/lookup').query({ number: '2200990011' }).set(bearer(accessToken));
  assert.equal(r.body.holder, 'María Y.');
});
