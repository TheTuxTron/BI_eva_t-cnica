import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import pino from 'pino';
import pinoHttp from 'pino-http';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { loadConfig } from './config.js';
import { openDb } from './db.js';
import { requestId } from './middleware/requestId.js';
import { requireAuth, requireAdmin } from './middleware/auth.js';
import { chaosMiddleware, defaultChaos } from './middleware/chaos.js';
import { createMetrics } from './middleware/metrics.js';
import { errorHandler } from './middleware/errorHandler.js';
import { createFxService } from './services/fx.js';
import { createPushService } from './services/push.js';
import { createAssistant } from './services/assistant.js';
import { authRoutes } from './routes/auth.js';
import { accountsRoutes } from './routes/accounts.js';
import { transfersRoutes } from './routes/transfers.js';
import { meRoutes, experienceRoutes, configRoutes, insightsRoutes, DEFAULT_FLAGS } from './routes/experience.js';
import { notificationsRoutes, devicesRoutes } from './routes/notifications.js';
import { microappsRoutes, microappApiRoutes } from './routes/microapps.js';
import { fxRoutes, assistantRoutes, adminRoutes, healthRoutes } from './routes/misc.js';

const publicDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'public');

export async function createApp(opts = {}) {
  const config = opts.config ?? loadConfig();
  const logger = opts.logger ?? pino({ level: config.logLevel, redact: ['req.headers.authorization', 'req.headers["x-admin-key"]', '*.password', '*.refreshToken'] });
  const db = opts.db ?? openDb(config.dbPath);
  const metrics = createMetrics();
  const state = { chaos: defaultChaos(), flags: { ...DEFAULT_FLAGS } };
  const fx = createFxService({ config, fetchImpl: opts.fetchImpl ?? fetch, metrics, logger });
  const push = await createPushService({ db, config, logger });
  const assistant = createAssistant({ config, fetchImpl: opts.fetchImpl ?? fetch, logger });
  const deps = { db, config, logger, metrics, state, fx, push, assistant };

  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use(requestId());
  app.use(pinoHttp({ logger, genReqId: (req) => req.id, autoLogging: { ignore: (req) => req.url.startsWith('/health') || req.url === '/metrics' } }));
  app.use(metrics.middleware);
  app.use(helmet({ contentSecurityPolicy: false, crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.use(cors({ exposedHeaders: ['X-Request-Id', 'Idempotent-Replayed', 'Retry-After'] }));
  app.use(express.json({ limit: '100kb' }));

  app.use('/microapps', express.static(join(publicDir, 'microapps'), { maxAge: '5m' }));
  app.use('/health', healthRoutes(deps));
  app.get('/metrics', async (_req, res) => { res.set('Content-Type', metrics.registry.contentType); res.end(await metrics.registry.metrics()); });
  app.use('/v1/admin', requireAdmin(config), adminRoutes(deps));

  app.use(chaosMiddleware(state, opts.chaosDeps));
  const auth = requireAuth(config);
  app.use('/v1/auth', authRoutes(deps));
  app.use('/v1/config', configRoutes(deps));
  app.use('/v1/microapp-api', microappApiRoutes(deps));
  app.use('/v1/me', auth, meRoutes(deps));
  app.use('/v1/accounts', auth, accountsRoutes(deps));
  app.use('/v1/transfers', auth, transfersRoutes(deps));
  app.use('/v1/experience', auth, experienceRoutes(deps));
  app.use('/v1/insights', auth, insightsRoutes(deps));
  app.use('/v1/notifications', auth, notificationsRoutes(deps));
  app.use('/v1/devices', auth, devicesRoutes(deps));
  app.use('/v1/microapps', auth, microappsRoutes(deps));
  app.use('/v1/fx', auth, fxRoutes(deps));
  app.use('/v1/assistant', auth, assistantRoutes(deps));

  app.use((req, res) => res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Ruta no encontrada', requestId: req.id } }));
  app.use(errorHandler(logger));
  return { app, deps };
}
