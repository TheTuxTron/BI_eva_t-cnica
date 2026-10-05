import { fmtUsd } from '../lib/money.js';

/**
 * Asistente financiero. Si hay ANTHROPIC_API_KEY usa un LLM con contexto MINIMIZADO
 * (solo agregados, sin números de cuenta ni cédula). Si no hay clave o el LLM falla,
 * responde con un motor de intenciones determinístico: la función nunca queda caída.
 */
export function createAssistant({ config, fetchImpl = fetch, logger }) {
  function rules(message, c) {
    const m = message.toLowerCase();
    if (/saldo|cu[aá]nto tengo|dinero/.test(m)) {
      return { reply: `Tu saldo consolidado es ${fmtUsd(c.totalBalanceCents)} en ${c.accounts} cuenta(s).`, suggestions: ['¿En qué gasto más?', 'Quiero transferir'] };
    }
    if (/gast|consum/.test(m)) {
      const top = Object.entries(c.byCategory).sort((a, b) => b[1] - a[1]).slice(0, 3);
      if (!top.length) return { reply: 'No veo gastos en los últimos 30 días.', suggestions: [] };
      return { reply: `En los últimos 30 días tus mayores gastos fueron: ${top.map(([k, v]) => `${k} (${fmtUsd(v)})`).join(', ')}.`, suggestions: ['¿Cómo puedo ahorrar más?'] };
    }
    if (/ahorr/.test(m)) {
      const rate = c.incomeCents ? Math.round(((c.incomeCents - c.spendCents) / c.incomeCents) * 100) : 0;
      return { reply: `Este mes tu tasa de ahorro es ${rate}%. Una meta realista es separar el 10% de cada ingreso apenas lo recibes. Puedes planificarlo en el simulador.`, suggestions: ['Abrir simulador'], action: { label: 'Abrir simulador', deeplink: 'microapp://simulador-credito?mode=ahorro' } };
    }
    if (/transfer|enviar|pagar/.test(m)) {
      return { reply: 'Puedes transferir a tus cuentas o a terceros de Kinti desde aquí.', suggestions: [], action: { label: 'Ir a transferir', deeplink: '/transfer' } };
    }
    if (/cr[eé]dito|pr[eé]stamo|cuota/.test(m)) {
      return { reply: 'Puedo ayudarte a estimar la cuota de un crédito con el simulador.', suggestions: [], action: { label: 'Simular crédito', deeplink: 'microapp://simulador-credito' } };
    }
    return { reply: 'Puedo ayudarte con tu saldo, tus gastos, metas de ahorro, transferencias o simular un crédito.', suggestions: ['¿Cuál es mi saldo?', '¿En qué gasto más?', '¿Cómo puedo ahorrar más?'] };
  }

  async function llm(message, c) {
    const system = `Eres el asistente financiero de Kinti, una banca digital en Ecuador. Responde en español, breve (máx. 3 frases), sin inventar datos ni dar asesoría de inversión personalizada. Contexto agregado del cliente: saldo total ${fmtUsd(c.totalBalanceCents)}; ingresos 30d ${fmtUsd(c.incomeCents)}; gastos 30d ${fmtUsd(c.spendCents)}; por categoría ${JSON.stringify(Object.fromEntries(Object.entries(c.byCategory).map(([k, v]) => [k, fmtUsd(v)])))}.`;
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), 8000);
    try {
      const res = await fetchImpl('https://api.anthropic.com/v1/messages', {
        method: 'POST', signal: ctrl.signal,
        headers: { 'content-type': 'application/json', 'x-api-key': config.anthropicApiKey, 'anthropic-version': '2023-06-01' },
        body: JSON.stringify({ model: config.anthropicModel, max_tokens: 300, system, messages: [{ role: 'user', content: message.slice(0, 500) }] }),
      });
      if (!res.ok) throw new Error(`llm ${res.status}`);
      const data = await res.json();
      const text = data.content?.filter((b) => b.type === 'text').map((b) => b.text).join('\n').trim();
      if (!text) throw new Error('llm vacío');
      return text;
    } finally {
      clearTimeout(t);
    }
  }

  async function answer(message, c) {
    const base = rules(message, c);
    if (!config.anthropicApiKey) return { ...base, source: 'rules' };
    try {
      return { ...base, reply: await llm(message, c), source: 'llm' };
    } catch (e) {
      logger?.warn({ err: e.message }, 'assistant_llm_fallback');
      return { ...base, source: 'rules-fallback' };
    }
  }

  return { answer };
}
