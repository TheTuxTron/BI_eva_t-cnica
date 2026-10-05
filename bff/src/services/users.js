import { unauthorized } from '../lib/errors.js';

/** Segmentación del cliente. En producción vendría de un CDP/modelo; aquí reglas explícitas y auditables. */
export function ageOf(birthDate, now = new Date()) {
  const b = new Date(birthDate);
  let age = now.getFullYear() - b.getFullYear();
  const m = now.getMonth() - b.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < b.getDate())) age--;
  return age;
}

export function computeSegment(user, totalBalanceCents, now = new Date()) {
  if (user.segment_override) return { segment: user.segment_override, reason: 'Segmento asignado manualmente' };
  if (totalBalanceCents >= 1_500_000) return { segment: 'premium', reason: 'Saldo consolidado superior a $15.000' };
  if (ageOf(user.birth_date, now) <= 27) return { segment: 'joven', reason: 'Cliente de 27 años o menos' };
  return { segment: 'clasico', reason: 'Segmento por defecto' };
}

export function getUser(db, id) {
  return db.prepare('SELECT * FROM users WHERE id = ?').get(id);
}

export function publicUser(u) {
  return { id: u.id, firstName: u.first_name, lastName: u.last_name, email: u.email, phone: maskPhone(u.phone), cedula: maskCedula(u.cedula), status: u.status };
}

export const maskCedula = (c) => `${c.slice(0, 2)}******${c.slice(-2)}`;
export const maskPhone = (p) => `${p.slice(0, 3)}****${p.slice(-3)}`;

export const DEFAULT_PREFS = { theme: 'system', hiddenSections: [], notificationsEnabled: true, balanceVisible: true };

export function getPrefs(db, userId) {
  const row = db.prepare('SELECT json FROM preferences WHERE user_id = ?').get(userId);
  return { ...DEFAULT_PREFS, ...(row ? JSON.parse(row.json) : {}) };
}

export function userContext(db, userId, now = new Date()) {
  const user = getUser(db, userId);
  // Token válido de un usuario que ya no existe (p. ej. base reiniciada): sesión inválida, no error 500.
  if (!user) throw unauthorized('Tu sesión ya no es válida, ingresa nuevamente');
  const accounts = db.prepare('SELECT * FROM accounts WHERE user_id = ? ORDER BY created_at, id').all(userId);
  const total = accounts.reduce((s, a) => s + a.balance_cents, 0);
  const { segment, reason } = computeSegment(user, total, now);
  return { user, accounts, totalBalanceCents: total, segment, segmentReason: reason, prefs: getPrefs(db, userId) };
}
