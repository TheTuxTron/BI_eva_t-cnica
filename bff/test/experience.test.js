import { test } from 'node:test';
import assert from 'node:assert/strict';
import { makeApp, login, bearer } from './helpers.js';

const types = (exp) => exp.sections.map((s) => s.type);

test('la experiencia de inicio cambia según el segmento', async () => {
  const { api } = await makeApp();
  const anaToken = (await login(api, 'ana@kinti.ec')).accessToken;
  const ana = await api.get('/v1/experience/home').set(bearer(anaToken));
  const carlosToken = (await login(api, 'carlos@kinti.ec')).accessToken;
  const carlos = await api.get('/v1/experience/home').set(bearer(carlosToken));
  assert.equal(ana.body.theme.segment, 'joven');
  assert.equal(carlos.body.theme.segment, 'premium');
  assert.notEqual(ana.body.theme.seedColor, carlos.body.theme.seedColor);
  assert.equal(carlos.body.sections.find((s) => s.type === 'quick_actions').props.actions[0].id, 'invest');
  assert.ok(types(carlos.body).indexOf('fx_rates') < types(carlos.body).indexOf('microapp_tile'));
  assert.ok(types(ana.body).indexOf('fx_rates') > types(ana.body).indexOf('microapp_tile'));
});

test('el comportamiento reordena las acciones rápidas', async () => {
  const { api } = await makeApp();
  const { accessToken } = await login(api, 'maria@kinti.ec');
  const before = await api.get('/v1/experience/home').set(bearer(accessToken));
  assert.equal(before.body.sections.find((s) => s.type === 'quick_actions').props.actions[0].id, 'transfer');
  await api.post('/v1/me/events').set(bearer(accessToken)).send({ events: Array(4).fill({ name: 'action_simulator' }) });
  const after = await api.get('/v1/experience/home').set(bearer(accessToken));
  assert.equal(after.body.sections.find((s) => s.type === 'quick_actions').props.actions[0].id, 'simulator');
});

test('las preferencias ocultan secciones (nunca el resumen de cuentas)', async () => {
  const { api } = await makeApp();
  const { accessToken } = await login(api);
  await api.put('/v1/me/preferences').set(bearer(accessToken)).send({ hiddenSections: ['insights', 'fx', 'accounts'] });
  const exp = await api.get('/v1/experience/home').set(bearer(accessToken));
  const ids = exp.body.sections.map((s) => s.id);
  assert.ok(!ids.includes('insights') && !ids.includes('fx'));
  assert.ok(ids.includes('accounts'));
});

test('una campaña nueva aparece sin publicar app y respeta el segmento', async () => {
  const { api } = await makeApp();
  const created = await api.post('/v1/admin/campaigns').set('X-Admin-Key', 'dev-admin-key')
    .send({ title: 'Black Friday Kinti', body: '10% de cashback', segments: ['joven'], priority: 99, ctaLabel: 'Ver', ctaDeeplink: '/assistant' });
  assert.equal(created.status, 201);
  const anaToken = (await login(api, 'ana@kinti.ec')).accessToken;
  const ana = await api.get('/v1/experience/home').set(bearer(anaToken));
  const carlosToken = (await login(api, 'carlos@kinti.ec')).accessToken;
  const carlos = await api.get('/v1/experience/home').set(bearer(carlosToken));
  assert.ok(ana.body.sections.some((s) => s.props.title === 'Black Friday Kinti'));
  assert.ok(!carlos.body.sections.some((s) => s.props.title === 'Black Friday Kinti'));
});

test('feature flag remoto apaga un módulo', async () => {
  const { api } = await makeApp();
  await api.put('/v1/admin/flags').set('X-Admin-Key', 'dev-admin-key').send({ fx: false });
  const token = (await login(api)).accessToken;
  const exp = await api.get('/v1/experience/home').set(bearer(token));
  assert.ok(!types(exp.body).includes('fx_rates'));
  const cfg = await api.get('/v1/config');
  assert.equal(cfg.body.flags.fx, false);
});

test('insights se calculan a partir de movimientos reales', async () => {
  const { api } = await makeApp();
  const token = (await login(api)).accessToken;
  const r = await api.get('/v1/insights').set(bearer(token));
  assert.ok(r.body.insights.length >= 2);
  assert.ok(r.body.summary.spendCents > 0);
});

test('asistente responde por reglas sin API key', async () => {
  const { api } = await makeApp();
  const token = (await login(api)).accessToken;
  const r = await api.post('/v1/assistant/messages').set(bearer(token)).send({ message: '¿cuál es mi saldo?' });
  assert.equal(r.body.source, 'rules');
  assert.match(r.body.reply, /saldo consolidado/);
});
