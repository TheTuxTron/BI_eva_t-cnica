export class HttpError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export const badRequest = (msg, details) => new HttpError(400, 'BAD_REQUEST', msg, details);
export const unauthorized = (msg = 'No autorizado') => new HttpError(401, 'UNAUTHORIZED', msg);
export const forbidden = (msg = 'Acceso denegado') => new HttpError(403, 'FORBIDDEN', msg);
export const notFound = (msg = 'Recurso no encontrado') => new HttpError(404, 'NOT_FOUND', msg);
export const conflict = (code, msg) => new HttpError(409, code, msg);
export const unprocessable = (code, msg, details) => new HttpError(422, code, msg, details);

/** Envuelve handlers async para que los errores lleguen al error handler. */
export const asyncH = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

/** Valida con un schema zod y lanza 400 con detalle por campo. */
export function parse(schema, data) {
  const r = schema.safeParse(data);
  if (!r.success) {
    const details = r.error.issues.map((i) => ({ field: i.path.join('.'), message: i.message }));
    throw badRequest('Datos inválidos', details);
  }
  return r.data;
}
