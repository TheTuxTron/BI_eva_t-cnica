import jwt from 'jsonwebtoken';
import { unauthorized, forbidden } from '../lib/errors.js';

export function signAccessToken(config, user) {
  return jwt.sign({ sub: user.id, typ: 'access' }, config.jwtSecret, {
    expiresIn: config.accessTtlSec, issuer: 'kinti-bff', audience: 'kinti-app',
  });
}

export function signMicroappToken(config, userId, appId, scopes) {
  return jwt.sign({ sub: userId, typ: 'microapp', scp: scopes }, config.jwtSecret, {
    expiresIn: config.microappTtlSec, issuer: 'kinti-bff', audience: `microapp:${appId}`,
  });
}

function bearer(req) {
  const h = req.get('authorization') ?? '';
  return h.startsWith('Bearer ') ? h.slice(7) : null;
}

/** Exige un access token de la app principal. */
export function requireAuth(config) {
  return (req, _res, next) => {
    const token = bearer(req);
    if (!token) return next(unauthorized('Falta el token de acceso'));
    try {
      const p = jwt.verify(token, config.jwtSecret, { issuer: 'kinti-bff', audience: 'kinti-app' });
      if (p.typ !== 'access') throw new Error('tipo inválido');
      req.userId = p.sub;
      next();
    } catch (e) {
      next(unauthorized(e.name === 'TokenExpiredError' ? 'Token expirado' : 'Token inválido'));
    }
  };
}

/** Exige un token de micro-app con audiencia y scope específicos (mínimo privilegio). */
export function requireMicroapp(config, appId, scope) {
  return (req, _res, next) => {
    const token = bearer(req);
    if (!token) return next(unauthorized());
    try {
      const p = jwt.verify(token, config.jwtSecret, { issuer: 'kinti-bff', audience: `microapp:${appId}` });
      if (p.typ !== 'microapp' || !p.scp?.includes(scope)) return next(forbidden('Scope insuficiente'));
      req.userId = p.sub;
      next();
    } catch {
      next(unauthorized('Token de micro-app inválido'));
    }
  };
}

export function requireAdmin(config) {
  return (req, _res, next) => (req.get('x-admin-key') === config.adminKey ? next() : next(forbidden('Admin key inválida')));
}
