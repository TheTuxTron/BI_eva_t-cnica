import { CircuitBreaker } from './circuitBreaker.js';

/**
 * Tipos de cambio reales desde Frankfurter (datos del Banco Central Europeo).
 * Estrategia: caché fresca (TTL) → upstream con timeout + circuit breaker → caché vencida
 * (stale) marcada como tal. Así una caída del tercero degrada, pero no rompe, la experiencia.
 */
export function createFxService({ config, fetchImpl = fetch, metrics, logger, now = () => Date.now() }) {
  const breaker = new CircuitBreaker({ failureThreshold: 3, resetTimeoutMs: 30_000, now });
  let cache = null; // { data, fetchedAt }
  const SYMBOLS = ['EUR', 'COP', 'PEN', 'MXN', 'GBP', 'CNY'];

  async function fetchUpstream() {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 4000);
    try {
      const url = `${config.fxBaseUrl}/latest?base=USD&symbols=${SYMBOLS.join(',')}`;
      const res = await fetchImpl(url, { signal: ctrl.signal });
      if (!res.ok) throw new Error(`fx upstream ${res.status}`);
      const body = await res.json();
      if (!body?.rates) throw new Error('fx payload inválido');
      return { base: body.base ?? 'USD', date: body.date, rates: body.rates };
    } finally {
      clearTimeout(timer);
    }
  }

  async function getRates() {
    const fresh = cache && now() - cache.fetchedAt < config.fxTtlSec * 1000;
    if (fresh) return { ...cache.data, fetchedAt: new Date(cache.fetchedAt).toISOString(), stale: false, source: 'cache' };
    try {
      const data = await breaker.exec(fetchUpstream);
      cache = { data, fetchedAt: now() };
      metrics?.upstream.inc({ dependency: 'frankfurter', result: 'ok' });
      return { ...data, fetchedAt: new Date(cache.fetchedAt).toISOString(), stale: false, source: 'upstream' };
    } catch (e) {
      metrics?.upstream.inc({ dependency: 'frankfurter', result: e.circuitOpen ? 'circuit_open' : 'error' });
      logger?.warn({ err: e.message, circuit: breaker.state }, 'fx_upstream_failed');
      if (cache) return { ...cache.data, fetchedAt: new Date(cache.fetchedAt).toISOString(), stale: true, source: 'stale-cache' };
      const err = new Error('fx_unavailable');
      err.unavailable = true;
      throw err;
    }
  }

  return { getRates, breaker, _setCache: (c) => { cache = c; } };
}
