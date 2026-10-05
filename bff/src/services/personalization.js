import { createHash } from 'node:crypto';

export const SDUI_SCHEMA_VERSION = 1;

// Identidad Banco Internacional: naranja #FF8100, café #614E4B, durazno #FFDEBC.
// La personalización varía la expresión (degradé, sólido, café) sin salir de la marca.
const THEMES = {
  joven: { seedColor: '#FF8100', accentColor: '#FFDEBC', hero: 'vibrant', label: 'Joven' },
  clasico: { seedColor: '#FF8100', accentColor: '#614E4B', hero: 'solid', label: 'Clásico' },
  premium: { seedColor: '#614E4B', accentColor: '#FF8100', hero: 'deep', label: 'Premium' },
};

const BASE_ACTIONS = {
  transfer: { id: 'transfer', label: 'Transferir', icon: 'swap_horiz', deeplink: '/transfer' },
  movements: { id: 'movements', label: 'Movimientos', icon: 'receipt_long', deeplink: '/accounts' },
  simulator: { id: 'simulator', label: 'Simular crédito', icon: 'calculate', deeplink: 'microapp://simulador-credito' },
  invest: { id: 'invest', label: 'Invertir', icon: 'trending_up', deeplink: 'microapp://simulador-credito?mode=inversion' },
  savings: { id: 'savings', label: 'Meta de ahorro', icon: 'savings', deeplink: 'microapp://simulador-credito?mode=ahorro' },
  assistant: { id: 'assistant', label: 'Asistente', icon: 'auto_awesome', deeplink: '/assistant' },
};

const DEFAULT_ACTION_ORDER = {
  joven: ['transfer', 'savings', 'assistant', 'movements'],
  clasico: ['transfer', 'movements', 'simulator', 'assistant'],
  premium: ['invest', 'transfer', 'movements', 'assistant'],
};

/** Bucket estable 0..99 por usuario/experimento para A/B testing sin estado. */
export function bucket(userId, experiment) {
  return parseInt(createHash('sha256').update(`${experiment}:${userId}`).digest('hex').slice(0, 8), 16) % 100;
}

function greeting(now, tz = 'America/Guayaquil') {
  const h = Number(new Intl.DateTimeFormat('en-US', { hour: 'numeric', hour12: false, timeZone: tz }).format(now)) % 24;
  return h < 12 ? 'Buenos días' : h < 19 ? 'Buenas tardes' : 'Buenas noches';
}

/**
 * Construye la experiencia de inicio (Server-Driven UI). La app solo conoce un catálogo
 * de componentes; el orden, contenido, visibilidad y tema se deciden aquí según
 * contexto (hora), perfil (segmento), comportamiento (eventos) y preferencias.
 */
export function buildHomeExperience({ ctx, eventCounts, campaigns, insights, flags, now = new Date() }) {
  const { user, segment, segmentReason, prefs } = ctx;
  const reasons = [segmentReason];
  const sections = [];

  sections.push({
    id: 'greeting', type: 'greeting',
    props: {
      title: `${greeting(now)}, ${user.first_name}`,
      subtitle: { joven: 'Cada dólar cuenta. Mira cómo vas este mes.', clasico: 'Tus finanzas, claras y al día.', premium: 'Tu patrimonio, en un vistazo.' }[segment],
    },
  });

  sections.push({ id: 'accounts', type: 'account_summary', props: { showTotal: ctx.accounts.length > 1, balanceVisible: prefs.balanceVisible } });

  // Acciones rápidas: orden por uso real del cliente; desempate con el orden del segmento.
  const order = DEFAULT_ACTION_ORDER[segment];
  const actions = [...order]
    .filter((id) => id !== 'assistant' || flags.assistant)
    .sort((a, b) => (eventCounts[`action_${b}`] ?? 0) - (eventCounts[`action_${a}`] ?? 0) || order.indexOf(a) - order.indexOf(b))
    .map((id) => BASE_ACTIONS[id]);
  if ((eventCounts.action_transfer ?? 0) >= 3) reasons.push('Usas mucho "Transferir": lo priorizamos');
  sections.push({ id: 'quick_actions', type: 'quick_actions', props: { actions } });

  // Campañas administradas desde backoffice: aparecen sin publicar una nueva versión de la app.
  const nowIso = now.toISOString();
  const eligible = campaigns
    .filter((c) => c.active && (!c.starts_at || c.starts_at <= nowIso) && (!c.ends_at || c.ends_at >= nowIso))
    .filter((c) => { const s = JSON.parse(c.segments); return s.length === 0 || s.includes(segment); })
    .filter((c) => !(c.id === 'cmp_all_seguridad' && prefs.notificationsEnabled && (eventCounts.push_enabled ?? 0) > 0))
    .sort((a, b) => b.priority - a.priority)
    .slice(0, 2);
  for (const c of eligible) {
    sections.push({
      id: `banner_${c.id}`, type: 'banner',
      props: { title: c.title, body: c.body, style: c.style, cta: c.cta_label ? { label: c.cta_label, deeplink: c.cta_deeplink } : null },
    });
  }

  // Experimento A/B: formato de la tarjeta de insight.
  const variant = bucket(user.id, 'insight_layout_v1') < 50 ? 'compact' : 'detailed';
  if (insights.length && flags.insights) sections.push({ id: 'insights', type: 'insight_card', props: { ...insights[0], variant } });

  const fxSection = { id: 'fx', type: 'fx_rates', props: { title: 'Tipo de cambio', symbols: segment === 'premium' ? ['EUR', 'GBP', 'CNY', 'MXN'] : ['EUR', 'COP', 'PEN'] } };
  const microTile = {
    id: 'microapp_simulator', type: 'microapp_tile',
    props: {
      appId: 'simulador-credito',
      title: { joven: 'Planifica tu meta de ahorro', clasico: 'Simula tu crédito', premium: 'Simula tu inversión a plazo' }[segment],
      description: 'Micro-app independiente integrada en tu banca.',
      deeplink: segment === 'premium' ? 'microapp://simulador-credito?mode=inversion' : segment === 'joven' ? 'microapp://simulador-credito?mode=ahorro' : 'microapp://simulador-credito',
    },
  };
  if (flags.fx && (segment === 'premium' || (eventCounts.screen_fx ?? 0) > 0)) {
    if (segment !== 'premium') reasons.push('Consultas el tipo de cambio: lo mostramos más arriba');
    sections.push(fxSection, microTile);
  } else {
    sections.push(microTile);
    if (flags.fx) sections.push(fxSection);
  }

  const visible = sections.filter((s) => !prefs.hiddenSections.includes(s.id) || s.id === 'accounts');

  return {
    schemaVersion: SDUI_SCHEMA_VERSION,
    screen: 'home',
    ttlSeconds: 300,
    theme: { segment, ...THEMES[segment], mode: prefs.theme },
    sections: visible,
    meta: { segment, generatedAt: now.toISOString(), experiments: { insight_layout_v1: variant }, reasons },
  };
}

export function eventCountsFor(db, userId) {
  const rows = db.prepare('SELECT name, COUNT(*) AS n FROM events WHERE user_id = ? GROUP BY name').all(userId);
  return Object.fromEntries(rows.map((r) => [r.name, r.n]));
}
