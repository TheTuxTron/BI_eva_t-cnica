import { Router } from 'express';
import { z } from 'zod';
import { asyncH, parse, notFound, badRequest } from '../lib/errors.js';
import { signMicroappToken, requireMicroapp } from '../middleware/auth.js';
import { userContext } from '../services/users.js';
import { frenchAmortization, savingsProjection, RATES } from '../services/credit.js';
import { toCents } from '../lib/money.js';

export const MICROAPPS = [{
  id: 'simulador-credito', name: 'Simulador financiero', version: '1.2.0', owner: 'Equipo Crédito Digital',
  description: 'Simula créditos, inversiones a plazo y metas de ahorro con tasas según tu perfil.',
  path: '/microapps/simulador-credito/index.html', scopes: ['profile.basic', 'credit.simulate'],
  allowedNavigation: ['/transfer', '/assistant', '/home'],
}];

/** Catálogo + emisión de sesión con token de alcance mínimo (aud y scope por micro-app). */
export function microappsRoutes({ db, config }) {
  const r = Router();
  r.get('/', (_req, res) => res.json({ items: MICROAPPS.map((m) => ({ ...m, url: `${config.publicBaseUrl}${m.path}` })) }));
  r.post('/:id/session', asyncH(async (req, res) => {
    const app = MICROAPPS.find((m) => m.id === req.params.id);
    if (!app) throw notFound('Micro-app no registrada');
    const ctx = userContext(db, req.userId);
    res.json({
      token: signMicroappToken(config, req.userId, app.id, app.scopes), expiresIn: config.microappTtlSec,
      url: `${config.publicBaseUrl}${app.path}`, allowedNavigation: app.allowedNavigation,
      context: { firstName: ctx.user.first_name, segment: ctx.segment, theme: ctx.prefs.theme },
    });
  }));
  return r;
}

const simSchema = z.object({
  mode: z.enum(['credito', 'inversion', 'ahorro']).default('credito'),
  amount: z.union([z.string(), z.number()]),
  months: z.coerce.number().int().min(1).max(84),
});

/** API propia de la micro-app (consumida desde la WebView con su token de alcance limitado). */
export function microappApiRoutes({ db, config }) {
  const r = Router();
  r.post('/simulador-credito/simulate', requireMicroapp(config, 'simulador-credito', 'credit.simulate'), asyncH(async (req, res) => {
    const { mode, amount, months } = parse(simSchema, req.body);
    const cents = toCents(amount);
    if (!Number.isFinite(cents) || cents <= 0 || cents > 10_000_000) throw badRequest('Monto fuera de rango');
    const { segment } = userContext(db, req.userId);
    const annualRate = RATES[mode][segment];
    if (mode === 'credito') return res.json({ mode, segment, annualRate, ...frenchAmortization({ amountCents: cents, months, annualRate }) });
    if (mode === 'ahorro') return res.json({ mode, segment, annualRate, ...savingsProjection({ monthlyCents: cents, months, annualRate }) });
    const interest = Math.round(cents * annualRate * (months / 12));
    return res.json({ mode, segment, annualRate, principalCents: cents, interestCents: interest, finalCents: cents + interest });
  }));
  return r;
}
