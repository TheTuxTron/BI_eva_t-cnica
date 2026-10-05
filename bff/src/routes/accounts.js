import { Router } from 'express';
import { asyncH, notFound, badRequest } from '../lib/errors.js';

export const toAccountDto = (a) => ({
  id: a.id, type: a.type, number: a.number, maskedNumber: `****${a.number.slice(-4)}`, alias: a.alias,
  currency: a.currency, balance: a.balance_cents / 100, balanceCents: a.balance_cents, availableCents: a.balance_cents,
});

export const toMovementDto = (m) => ({
  id: m.id, accountId: m.account_id, amountCents: m.amount_cents, balanceAfterCents: m.balance_after_cents,
  description: m.description, category: m.category, channel: m.channel, createdAt: m.created_at,
});

export function accountsRoutes({ db }) {
  const r = Router();

  const owned = (userId, id) => {
    const a = db.prepare('SELECT * FROM accounts WHERE id = ? AND user_id = ?').get(id, userId);
    if (!a) throw notFound('Cuenta no encontrada');
    return a;
  };

  r.get('/', asyncH(async (req, res) => {
    const rows = db.prepare('SELECT * FROM accounts WHERE user_id = ? ORDER BY created_at, id').all(req.userId);
    const totalCents = rows.reduce((s, a) => s + a.balance_cents, 0);
    res.json({ items: rows.map(toAccountDto), totalCents, asOf: new Date().toISOString() });
  }));

  // Verificación de destinatario antes de transferir (muestra el titular enmascarado).
  r.get('/lookup', asyncH(async (req, res) => {
    const number = String(req.query.number ?? '');
    if (!/^\d{10}$/.test(number)) throw badRequest('Número de cuenta inválido');
    const a = db.prepare('SELECT a.number, a.type, u.first_name, u.last_name FROM accounts a JOIN users u ON u.id = a.user_id WHERE a.number = ?').get(number);
    if (!a) throw notFound('No encontramos esa cuenta en Kinti');
    res.json({ number: a.number, type: a.type, holder: `${a.first_name} ${a.last_name[0]}.` });
  }));

  r.get('/:id', asyncH(async (req, res) => res.json(toAccountDto(owned(req.userId, req.params.id)))));

  // Paginación por cursor (estable ante inserciones nuevas, a diferencia de offset).
  r.get('/:id/movements', asyncH(async (req, res) => {
    const acc = owned(req.userId, req.params.id);
    const limit = Math.min(Math.max(Number(req.query.limit) || 20, 1), 50);
    const category = req.query.category ? String(req.query.category) : null;
    let cursorAt = '9999'; let cursorId = '~';
    if (req.query.cursor) {
      try { [cursorAt, cursorId] = Buffer.from(String(req.query.cursor), 'base64url').toString().split('|'); } catch { throw badRequest('Cursor inválido'); }
      if (!cursorAt || !cursorId) throw badRequest('Cursor inválido');
    }
    const rows = db.prepare(`SELECT * FROM movements WHERE account_id = ? AND (created_at < ? OR (created_at = ? AND id < ?))
      ${category ? 'AND category = ?' : ''} ORDER BY created_at DESC, id DESC LIMIT ?`)
      .all(...[acc.id, cursorAt, cursorAt, cursorId, ...(category ? [category] : []), limit + 1]);
    const hasMore = rows.length > limit;
    const page = rows.slice(0, limit);
    const last = page.at(-1);
    res.json({ items: page.map(toMovementDto), nextCursor: hasMore ? Buffer.from(`${last.created_at}|${last.id}`).toString('base64url') : null });
  }));

  return r;
}
