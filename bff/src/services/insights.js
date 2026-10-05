import { fmtUsd } from '../lib/money.js';

const LABEL = {
  alimentacion: 'supermercado', restaurantes: 'restaurantes', transporte: 'transporte', servicios: 'servicios básicos',
  compras: 'compras', salud: 'salud', entretenimiento: 'entretenimiento',
};

/**
 * Motor de insights: procesa los movimientos reales del cliente (no respuestas fijas)
 * comparando los últimos 30 días contra los 30 anteriores.
 */
export function computeInsights(db, userId, now = new Date()) {
  const d30 = new Date(now.getTime() - 30 * 864e5).toISOString();
  const d60 = new Date(now.getTime() - 60 * 864e5).toISOString();
  const rows = db.prepare(`
    SELECT m.category, m.amount_cents, m.created_at FROM movements m
    JOIN accounts a ON a.id = m.account_id WHERE a.user_id = ? AND m.created_at >= ?`).all(userId, d60);

  const cur = {}; const prev = {}; let income = 0; let spend = 0;
  for (const r of rows) {
    const isCur = r.created_at >= d30;
    if (r.amount_cents > 0) { if (isCur && r.category === 'ingresos') income += r.amount_cents; continue; }
    if (!LABEL[r.category]) continue;
    const bucket = isCur ? cur : prev;
    bucket[r.category] = (bucket[r.category] ?? 0) + -r.amount_cents;
    if (isCur) spend += -r.amount_cents;
  }

  const insights = [];
  let best = null;
  for (const [cat, amount] of Object.entries(cur)) {
    const before = prev[cat] ?? 0;
    if (before < 2000) continue;
    const pct = (amount - before) / before;
    if (pct >= 0.15 && amount - before >= 2000 && (!best || pct > best.pct)) best = { cat, pct, amount, before };
  }
  if (best) {
    insights.push({
      id: `spend_up_${best.cat}`, tone: 'warning', icon: 'trending_up',
      title: `Gastaste ${Math.round(best.pct * 100)}% más en ${LABEL[best.cat]}`,
      body: `${fmtUsd(best.amount)} en los últimos 30 días frente a ${fmtUsd(best.before)} del periodo anterior.`,
      deeplink: `/accounts?category=${best.cat}`,
    });
  }
  const top = Object.entries(cur).sort((a, b) => b[1] - a[1])[0];
  if (top) {
    insights.push({
      id: `top_${top[0]}`, tone: 'info', icon: 'pie_chart',
      title: `Tu mayor gasto del mes: ${LABEL[top[0]]}`,
      body: `Representa el ${Math.round((top[1] / Math.max(spend, 1)) * 100)}% de tus gastos (${fmtUsd(top[1])}).`,
      deeplink: `/accounts?category=${top[0]}`,
    });
  }
  if (income > 0) {
    const rate = (income - spend) / income;
    insights.push(rate > 0
      ? { id: 'savings_rate', tone: 'positive', icon: 'savings', title: `Este mes ahorraste el ${Math.round(rate * 100)}% de tus ingresos`, body: 'Mantener al menos un 10% te ayuda a construir un fondo de emergencia.', deeplink: 'microapp://simulador-credito?mode=ahorro' }
      : { id: 'savings_rate', tone: 'warning', icon: 'savings', title: 'Este mes gastaste más de lo que ingresó', body: `La diferencia fue de ${fmtUsd(spend - income)}. Revisa tus gastos recurrentes.`, deeplink: '/accounts' });
  }
  return { insights, summary: { incomeCents: income, spendCents: spend, byCategory: cur } };
}
