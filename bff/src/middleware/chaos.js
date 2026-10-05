/**
 * Fault injection controlado (solo para demo/QA). Permite demostrar en vivo el
 * comportamiento de la app ante alta latencia, errores intermitentes y caída parcial
 * de un dominio, sin tocar código.
 */
export const GROUPS = {
  auth: '/v1/auth', accounts: '/v1/accounts', transfers: '/v1/transfers', experience: '/v1/experience',
  fx: '/v1/fx', notifications: '/v1/notifications', insights: '/v1/insights', assistant: '/v1/assistant',
  microapps: '/v1/microapps', me: '/v1/me',
};

export function defaultChaos() {
  return { enabled: false, latencyMs: 0, jitterMs: 0, errorRate: 0, groups: [], outages: [] };
}

export function groupOf(path) {
  return Object.entries(GROUPS).find(([, prefix]) => path.startsWith(prefix))?.[0];
}

export function chaosMiddleware(state, { random = Math.random, sleep = (ms) => new Promise((r) => setTimeout(r, ms)) } = {}) {
  return async (req, res, next) => {
    const c = state.chaos;
    if (!c.enabled) return next();
    const group = groupOf(req.path);
    if (!group) return next();
    if (c.outages.includes(group)) {
      res.setHeader('Retry-After', '10');
      return res.status(503).json({ error: { code: 'SERVICE_UNAVAILABLE', message: `El dominio ${group} no está disponible`, requestId: req.id } });
    }
    const targeted = c.groups.length === 0 || c.groups.includes(group);
    if (!targeted) return next();
    const delay = c.latencyMs + Math.round(random() * c.jitterMs);
    if (delay > 0) await sleep(delay);
    if (c.errorRate > 0 && random() < c.errorRate) {
      return res.status(503).json({ error: { code: 'TRANSIENT_FAILURE', message: 'Falla transitoria inyectada', requestId: req.id } });
    }
    next();
  };
}
