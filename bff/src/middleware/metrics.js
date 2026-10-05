import client from 'prom-client';

export function createMetrics() {
  const registry = new client.Registry();
  client.collectDefaultMetrics({ register: registry });
  const httpDuration = new client.Histogram({
    name: 'http_request_duration_seconds', help: 'Duración de requests HTTP',
    labelNames: ['method', 'route', 'status'], buckets: [0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10], registers: [registry],
  });
  const logins = new client.Counter({ name: 'auth_logins_total', help: 'Intentos de login', labelNames: ['result'], registers: [registry] });
  const transfers = new client.Counter({ name: 'transfers_total', help: 'Transferencias', labelNames: ['result'], registers: [registry] });
  const upstream = new client.Counter({ name: 'upstream_calls_total', help: 'Llamadas a dependencias externas', labelNames: ['dependency', 'result'], registers: [registry] });
  const clientEvents = new client.Counter({ name: 'client_events_total', help: 'Eventos de UX reportados por la app', labelNames: ['name'], registers: [registry] });

  const middleware = (req, res, next) => {
    const end = httpDuration.startTimer();
    res.on('finish', () => {
      const route = req.route?.path ? `${req.baseUrl}${req.route.path}` : 'unmatched';
      end({ method: req.method, route, status: res.statusCode });
    });
    next();
  };
  return { registry, middleware, logins, transfers, upstream, clientEvents };
}
