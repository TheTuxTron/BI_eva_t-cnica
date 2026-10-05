import { HttpError } from '../lib/errors.js';

export function errorHandler(logger) {
  // eslint-disable-next-line no-unused-vars
  return (err, req, res, _next) => {
    if (err instanceof HttpError) {
      return res.status(err.status).json({ error: { code: err.code, message: err.message, details: err.details, requestId: req.id } });
    }
    if (err?.type === 'entity.parse.failed') {
      return res.status(400).json({ error: { code: 'BAD_JSON', message: 'JSON inválido', requestId: req.id } });
    }
    logger.error({ err, requestId: req.id }, 'unhandled_error');
    res.status(500).json({ error: { code: 'INTERNAL', message: 'Ocurrió un error inesperado', requestId: req.id } });
  };
}
