import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { asyncH, parse, badRequest, unauthorized, conflict, unprocessable, notFound } from '../lib/errors.js';
import { isValidCedula } from '../lib/cedula.js';
import { hashPassword, verifyPassword, sha256, newId, newOtp, newOpaqueToken } from '../lib/crypto.js';
import { signAccessToken } from '../middleware/auth.js';
import { ageOf, publicUser } from '../services/users.js';
import { tx } from '../db.js';

const PASSWORD = z.string().min(8, 'Mínimo 8 caracteres').regex(/[A-Z]/, 'Debe incluir una mayúscula').regex(/[0-9]/, 'Debe incluir un número');

const registerSchema = z.object({
  cedula: z.string().refine(isValidCedula, 'Cédula ecuatoriana inválida'),
  firstName: z.string().trim().min(2).max(60),
  lastName: z.string().trim().min(2).max(60),
  email: z.string().trim().toLowerCase().email('Correo inválido'),
  phone: z.string().regex(/^09\d{8}$/, 'Celular inválido (09XXXXXXXX)'),
  birthDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  password: PASSWORD,
  acceptTerms: z.literal(true, { errorMap: () => ({ message: 'Debes aceptar los términos' }) }),
});

export function authRoutes({ db, config, metrics, push, logger }) {
  const r = Router();
  const limiter = rateLimit({ windowMs: 60_000, limit: config.env === 'test' ? 1000 : 20, standardHeaders: 'draft-7', legacyHeaders: false });

  function issueTokens(user, family = newId('fam')) {
    const refreshToken = newOpaqueToken();
    db.prepare('INSERT INTO refresh_tokens (token_hash,user_id,family,expires_at) VALUES (?,?,?,?)')
      .run(sha256(refreshToken), user.id, family, Date.now() + config.refreshTtlSec * 1000);
    return { accessToken: signAccessToken(config, user), refreshToken, expiresIn: config.accessTtlSec, tokenType: 'Bearer', user: publicUser(user) };
  }

  function createOtp(userId) {
    const code = newOtp();
    db.prepare('INSERT OR REPLACE INTO otps (user_id,code_hash,expires_at,attempts) VALUES (?,?,?,0)').run(userId, sha256(code), Date.now() + 5 * 60_000);
    logger.info({ userId, ...(config.exposeOtp ? { otp: code } : {}) }, 'otp_sent');
    return code;
  }

  r.post('/register', limiter, asyncH(async (req, res) => {
    const body = parse(registerSchema, req.body);
    if (ageOf(body.birthDate) < 18) throw unprocessable('UNDERAGE', 'Debes ser mayor de edad para abrir una cuenta');
    const dup = db.prepare('SELECT id, status FROM users WHERE cedula = ? OR email = ?').get(body.cedula, body.email);
    if (dup && dup.status === 'active') throw conflict('ALREADY_REGISTERED', 'Ya existe un cliente con esa cédula o correo');
    const id = dup?.id ?? newId('usr');
    if (dup) db.prepare('DELETE FROM users WHERE id = ?').run(id); // re-intento de un onboarding no completado
    db.prepare(`INSERT INTO users (id,cedula,email,phone,first_name,last_name,birth_date,password_hash,status,created_at)
      VALUES (?,?,?,?,?,?,?,?, 'pending', ?)`).run(id, body.cedula, body.email, body.phone, body.firstName, body.lastName, body.birthDate, hashPassword(body.password), new Date().toISOString());
    const code = createOtp(id);
    res.status(201).json({ userId: id, otpChannel: 'sms', maskedPhone: `${body.phone.slice(0, 3)}****${body.phone.slice(-3)}`, ...(config.exposeOtp ? { devOtp: code } : {}) });
  }));

  r.post('/otp/resend', limiter, asyncH(async (req, res) => {
    const { userId } = parse(z.object({ userId: z.string() }), req.body);
    const u = db.prepare("SELECT id FROM users WHERE id = ? AND status = 'pending'").get(userId);
    if (!u) throw notFound('Onboarding no encontrado');
    const code = createOtp(userId);
    res.json({ ok: true, ...(config.exposeOtp ? { devOtp: code } : {}) });
  }));

  r.post('/otp/verify', limiter, asyncH(async (req, res) => {
    const { userId, code } = parse(z.object({ userId: z.string(), code: z.string().regex(/^\d{6}$/) }), req.body);
    const otp = db.prepare('SELECT * FROM otps WHERE user_id = ?').get(userId);
    if (!otp || otp.expires_at < Date.now()) throw unprocessable('OTP_EXPIRED', 'El código expiró, solicita uno nuevo');
    if (otp.attempts >= 5) throw unprocessable('OTP_LOCKED', 'Demasiados intentos, solicita un nuevo código');
    if (otp.code_hash !== sha256(code)) {
      db.prepare('UPDATE otps SET attempts = attempts + 1 WHERE user_id = ?').run(userId);
      throw unprocessable('OTP_INVALID', 'Código incorrecto');
    }
    const user = tx(db, () => {
      db.prepare("UPDATE users SET status = 'active' WHERE id = ?").run(userId);
      db.prepare('DELETE FROM otps WHERE user_id = ?').run(userId);
      // Apertura digital de cuenta de ahorros con número único.
      let number;
      do { number = `22${String(Math.floor(Math.random() * 1e8)).padStart(8, '0')}`; } while (db.prepare('SELECT 1 FROM accounts WHERE number = ?').get(number));
      const accId = newId('acc');
      const now = new Date().toISOString();
      db.prepare("INSERT INTO accounts (id,user_id,type,number,alias,currency,balance_cents,created_at) VALUES (?,?, 'savings', ?, 'Mi cuenta Kinti', 'USD', 1000, ?)").run(accId, userId, number, now);
      db.prepare("INSERT INTO movements (id,account_id,amount_cents,balance_after_cents,description,category,channel,created_at) VALUES (?,?,1000,1000,'Bono de bienvenida','ingresos','sistema',?)").run(newId('mov'), accId, now);
      return db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    });
    await push.notify(user.id, { title: 'Tu cuenta está lista', body: 'Te regalamos $10 de bienvenida. ¡Explora Kinti!', deeplink: '/home' });
    res.status(201).json(issueTokens(user));
  }));

  r.post('/login', limiter, asyncH(async (req, res) => {
    const { username, password } = parse(z.object({ username: z.string().trim().min(3), password: z.string().min(1) }), req.body);
    const u = db.prepare('SELECT * FROM users WHERE email = ? OR cedula = ?').get(username.toLowerCase(), username);
    if (!u || !verifyPassword(password, u.password_hash)) {
      metrics.logins.inc({ result: 'invalid' });
      throw unauthorized('Usuario o contraseña incorrectos');
    }
    if (u.status !== 'active') {
      metrics.logins.inc({ result: 'pending' });
      throw unprocessable('ONBOARDING_PENDING', 'Completa la verificación de tu cuenta', { userId: u.id });
    }
    metrics.logins.inc({ result: 'ok' });
    res.json(issueTokens(u));
  }));

  r.post('/refresh', asyncH(async (req, res) => {
    const { refreshToken } = parse(z.object({ refreshToken: z.string().min(10) }), req.body);
    const row = db.prepare('SELECT * FROM refresh_tokens WHERE token_hash = ?').get(sha256(refreshToken));
    if (!row) throw unauthorized('Sesión inválida');
    if (row.revoked) {
      // Reúso de un refresh token ya rotado: posible robo. Se revoca toda la familia.
      db.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE family = ?').run(row.family);
      logger.warn({ userId: row.user_id }, 'refresh_token_reuse_detected');
      throw unauthorized('Sesión revocada por seguridad');
    }
    if (row.expires_at < Date.now()) throw unauthorized('Sesión expirada');
    db.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE token_hash = ?').run(row.token_hash);
    const u = db.prepare('SELECT * FROM users WHERE id = ?').get(row.user_id);
    res.json(issueTokens(u, row.family));
  }));

  r.post('/logout', asyncH(async (req, res) => {
    const { refreshToken } = req.body ?? {};
    if (typeof refreshToken !== 'string') throw badRequest('refreshToken requerido');
    const row = db.prepare('SELECT family FROM refresh_tokens WHERE token_hash = ?').get(sha256(refreshToken));
    if (row) db.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE family = ?').run(row.family);
    res.status(204).end();
  }));

  return r;
}
