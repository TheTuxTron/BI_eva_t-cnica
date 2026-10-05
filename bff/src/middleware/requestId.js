import { randomUUID } from 'node:crypto';

/** Propaga X-Request-Id (correlación extremo a extremo: app → BFF → logs). */
export function requestId() {
  return (req, res, next) => {
    const incoming = req.get('x-request-id');
    req.id = incoming && /^[\w-]{8,64}$/.test(incoming) ? incoming : randomUUID();
    res.setHeader('X-Request-Id', req.id);
    next();
  };
}
