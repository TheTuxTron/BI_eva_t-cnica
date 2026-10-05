import { Router } from 'express';
import { z } from 'zod';
import { asyncH, parse, badRequest, notFound, unprocessable, conflict } from '../lib/errors.js';
import { toCents, fmtUsd } from '../lib/money.js';
import { newId, sha256 } from '../lib/crypto.js';
import { tx } from '../db.js';
import { toAccountDto } from './accounts.js';

const schema = z.object({
  fromAccountId: z.string().min(3),
  toAccountNumber: z.string().regex(/^\d{10}$/, 'Número de cuenta inválido'),
  amount: z.union([z.string(), z.number()]),
  description: z.string().trim().max(60).optional().default('Transferencia'),
});

export function transfersRoutes({ db, config, metrics, push }) {
  const r = Router();

  r.post('/', asyncH(async (req, res) => {
    const key = req.get('idempotency-key');
    if (!key || !/^[\w-]{8,64}$/.test(key)) throw badRequest('Header Idempotency-Key requerido');
    const body = parse(schema, req.body);
    const requestHash = sha256(JSON.stringify(body));

    // Idempotencia: si la app reintenta (timeout, reconexión) devolvemos la MISMA respuesta.
    const prev = db.prepare('SELECT * FROM idempotency WHERE key = ? AND user_id = ?').get(key, req.userId);
    if (prev) {
      if (prev.request_hash !== requestHash) throw conflict('IDEMPOTENCY_MISMATCH', 'La clave de idempotencia ya se usó con otros datos');
      res.setHeader('Idempotent-Replayed', 'true');
      return res.status(prev.status).json(JSON.parse(prev.response_json));
    }

    const cents = toCents(body.amount);
    if (!Number.isFinite(cents) || cents <= 0) throw badRequest('Monto inválido');

    const result = tx(db, () => {
      const from = db.prepare('SELECT * FROM accounts WHERE id = ? AND user_id = ?').get(body.fromAccountId, req.userId);
      if (!from) throw notFound('Cuenta origen no encontrada');
      const to = db.prepare('SELECT * FROM accounts WHERE number = ?').get(body.toAccountNumber);
      if (!to) throw notFound('Cuenta destino no encontrada');
      if (to.id === from.id) throw unprocessable('SAME_ACCOUNT', 'La cuenta origen y destino no pueden ser la misma');
      if (from.balance_cents < cents) throw unprocessable('INSUFFICIENT_FUNDS', 'Saldo insuficiente');
      const since = new Date(Date.now() - 864e5).toISOString();
      const { used } = db.prepare("SELECT COALESCE(SUM(-amount_cents),0) AS used FROM movements WHERE account_id = ? AND channel = 'transferencia' AND amount_cents < 0 AND created_at >= ?").get(from.id, since);
      if (used + cents > config.dailyTransferLimitCents) throw unprocessable('DAILY_LIMIT', `Superas tu límite diario de ${fmtUsd(config.dailyTransferLimitCents)}`);

      const now = new Date().toISOString();
      const fromBal = from.balance_cents - cents;
      const toBal = to.balance_cents + cents;
      db.prepare('UPDATE accounts SET balance_cents = ? WHERE id = ?').run(fromBal, from.id);
      db.prepare('UPDATE accounts SET balance_cents = ? WHERE id = ?').run(toBal, to.id);
      const ins = db.prepare("INSERT INTO movements (id,account_id,amount_cents,balance_after_cents,description,category,channel,created_at) VALUES (?,?,?,?,?, 'transferencias', 'transferencia', ?)");
      const movId = newId('mov');
      ins.run(movId, from.id, -cents, fromBal, `${body.description} a ****${to.number.slice(-4)}`, now);
      ins.run(newId('mov'), to.id, cents, toBal, `${body.description} de ****${from.number.slice(-4)}`, now);
      const response = {
        id: newId('trf'), status: 'completed', amountCents: cents, createdAt: now, movementId: movId,
        from: toAccountDto({ ...from, balance_cents: fromBal }), toMaskedNumber: `****${to.number.slice(-4)}`,
      };
      db.prepare('INSERT INTO idempotency (key,user_id,request_hash,status,response_json,created_at) VALUES (?,?,?,?,?,?)').run(key, req.userId, requestHash, 201, JSON.stringify(response), now);
      return { response, toUserId: to.user_id, from, to };
    });

    metrics.transfers.inc({ result: 'ok' });
    await push.notify(req.userId, { title: 'Transferencia enviada', body: `Enviaste ${fmtUsd(cents)} a la cuenta ****${result.to.number.slice(-4)}.`, deeplink: `/accounts/${result.from.id}` });
    if (result.toUserId !== req.userId) {
      await push.notify(result.toUserId, { title: 'Recibiste dinero', body: `Te transfirieron ${fmtUsd(cents)} a tu cuenta ****${result.to.number.slice(-4)}.`, deeplink: `/accounts/${result.to.id}` });
    }
    res.status(201).json(result.response);
  }));

  return r;
}
