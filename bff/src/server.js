import { createApp } from './app.js';
import { loadConfig } from './config.js';
import { DEMO_USERS, DEMO_PASSWORD } from './seed.js';

const config = loadConfig();
if (config.env === 'production' && config.jwtSecret === 'dev-only-secret-change-me') {
  console.error('JWT_SECRET es obligatorio en producción');
  process.exit(1);
}
const { app, deps } = await createApp({ config });
const server = app.listen(config.port, () => {
  deps.logger.info({ port: config.port, baseUrl: config.publicBaseUrl || '(deducida del Host de cada petición)', db: config.dbPath }, 'kinti_bff_started');
  deps.logger.info({ users: DEMO_USERS.map((u) => u.email), password: DEMO_PASSWORD }, 'demo_users');
});

// Apagado ordenado: deja terminar requests en curso antes de cerrar (deploys sin cortes).
for (const sig of ['SIGTERM', 'SIGINT']) {
  process.on(sig, () => {
    deps.logger.info({ sig }, 'shutting_down');
    server.close(() => { deps.db.close(); process.exit(0); });
    setTimeout(() => process.exit(1), 10_000).unref();
  });
}
