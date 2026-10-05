import { randomBytes, scryptSync, timingSafeEqual, createHash, randomInt, randomUUID } from 'node:crypto';

export function hashPassword(password) {
  const salt = randomBytes(16);
  const hash = scryptSync(password, salt, 32);
  return `scrypt$${salt.toString('hex')}$${hash.toString('hex')}`;
}

export function verifyPassword(password, stored) {
  const [, saltHex, hashHex] = String(stored).split('$');
  if (!saltHex || !hashHex) return false;
  const expected = Buffer.from(hashHex, 'hex');
  const actual = scryptSync(password, Buffer.from(saltHex, 'hex'), expected.length);
  return timingSafeEqual(expected, actual);
}

export const sha256 = (v) => createHash('sha256').update(v).digest('hex');
export const newId = (prefix) => `${prefix}_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
export const newOtp = () => String(randomInt(0, 1_000_000)).padStart(6, '0');
export const newOpaqueToken = () => randomBytes(32).toString('base64url');
