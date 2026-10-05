const port = Number(process.env.PORT ?? 8080);

export function loadConfig(overrides = {}) {
  return {
    env: process.env.NODE_ENV ?? 'development',
    port,
    publicBaseUrl: process.env.PUBLIC_BASE_URL ?? `http://localhost:${port}`,
    jwtSecret: process.env.JWT_SECRET ?? 'dev-only-secret-change-me',
    accessTtlSec: Number(process.env.ACCESS_TTL_SEC ?? 900),
    refreshTtlSec: Number(process.env.REFRESH_TTL_SEC ?? 60 * 60 * 24 * 7),
    microappTtlSec: Number(process.env.MICROAPP_TTL_SEC ?? 300),
    dbPath: process.env.DB_PATH ?? ':memory:',
    adminKey: process.env.ADMIN_KEY ?? 'dev-admin-key',
    // Solo para entornos de demo: devuelve el OTP en la respuesta para no depender de un proveedor SMS.
    exposeOtp: (process.env.EXPOSE_OTP ?? 'true') === 'true',
    fxBaseUrl: process.env.FX_BASE_URL ?? 'https://api.frankfurter.dev/v1',
    fxTtlSec: Number(process.env.FX_TTL_SEC ?? 3600),
    anthropicApiKey: process.env.ANTHROPIC_API_KEY ?? '',
    anthropicModel: process.env.ANTHROPIC_MODEL ?? 'claude-haiku-4-5-20251001',
    firebaseServiceAccount: process.env.FIREBASE_SERVICE_ACCOUNT ?? '',
    logLevel: process.env.LOG_LEVEL ?? 'info',
    dailyTransferLimitCents: Number(process.env.DAILY_TRANSFER_LIMIT_CENTS ?? 300000),
    ...overrides,
  };
}
