import { hashPassword, newId } from './lib/crypto.js';
import { buildCedula } from './lib/cedula.js';

export const DEMO_PASSWORD = 'Kinti2026!';

/** PRNG determinístico (mulberry32) para que los datos semilla sean reproducibles. */
function rng(seedNum) {
  let a = seedNum;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const MERCHANTS = {
  alimentacion: ['Supermaxi', 'Tía', 'Mi Comisariato', 'Mercado La Condamine'],
  restaurantes: ['Café de la Vaca', 'Pizzería Napoli', 'KFC', 'Encebollado Don Lucho', 'Sushi Bar Kioto'],
  transporte: ['Recarga Metro Quito', 'Uber', 'Gasolinera Primax', 'Cabify'],
  servicios: ['CNEL Luz', 'EMAPA Agua', 'Netlife Internet', 'Claro Plan'],
  compras: ['Amazon', 'De Prati', 'Marathon Sports', 'Kywi'],
  salud: ['Fybeca', 'Pharmacys', 'Laboratorio Clínico'],
  entretenimiento: ['Netflix', 'Spotify', 'Cinemark', 'Steam'],
};

const PERSONAS = [
  {
    key: 'ana', first: 'Ana', last: 'Guamán', email: 'ana@kinti.ec', phone: '0991111111',
    birth: '2001-04-12', cedula: buildCedula('060412345'),
    accounts: [{ type: 'savings', alias: 'Ahorro principal', number: '2200112233', start: 180000 }],
    salary: 95000, spend: { restaurantes: 7, entretenimiento: 5, transporte: 8, alimentacion: 5, compras: 3 },
  },
  {
    key: 'carlos', first: 'Carlos', last: 'Andrade', email: 'carlos@kinti.ec', phone: '0992222222',
    birth: '1979-09-03', cedula: buildCedula('170345678'),
    accounts: [
      { type: 'checking', alias: 'Corriente empresarial', number: '3300445566', start: 2850000 },
      { type: 'savings', alias: 'Ahorro inversión', number: '2200778899', start: 4120000 },
    ],
    salary: 620000, spend: { restaurantes: 6, servicios: 4, compras: 5, salud: 2, alimentacion: 6, transporte: 4 },
  },
  {
    key: 'maria', first: 'María', last: 'Yánez', email: 'maria@kinti.ec', phone: '0993333333',
    birth: '1990-01-21', cedula: buildCedula('180123456'),
    accounts: [{ type: 'savings', alias: 'Mi ahorro', number: '2200990011', start: 420000 }],
    salary: 160000, spend: { alimentacion: 8, servicios: 4, salud: 3, transporte: 6, compras: 2 },
  },
];

const AMOUNT_RANGE = {
  alimentacion: [1500, 9500], restaurantes: [600, 4800], transporte: [100, 3500],
  servicios: [1800, 6500], compras: [1200, 15000], salud: [500, 6000], entretenimiento: [499, 1599],
};

export function seed(db, now = new Date()) {
  const pwd = hashPassword(DEMO_PASSWORD);
  const insUser = db.prepare(`INSERT INTO users (id,cedula,email,phone,first_name,last_name,birth_date,password_hash,status,created_at)
    VALUES (?,?,?,?,?,?,?,?, 'active', ?)`);
  const insAcc = db.prepare(`INSERT INTO accounts (id,user_id,type,number,alias,currency,balance_cents,created_at) VALUES (?,?,?,?,?, 'USD', ?, ?)`);
  const insMov = db.prepare(`INSERT INTO movements (id,account_id,amount_cents,balance_after_cents,description,category,channel,created_at) VALUES (?,?,?,?,?,?,?,?)`);
  const created = new Date(now.getTime() - 400 * 864e5).toISOString();

  PERSONAS.forEach((p, idx) => {
    const userId = `usr_${p.key}`;
    insUser.run(userId, p.cedula, p.email, p.phone, p.first, p.last, p.birth, pwd, created);
    p.accounts.forEach((a, aIdx) => {
      const accId = `acc_${p.key}_${aIdx + 1}`;
      const rand = rng(1000 + idx * 31 + aIdx);
      // Genera 75 días de movimientos; el gasto de los últimos 30 días crece en una categoría
      // para que el motor de insights tenga algo real que detectar.
      const txs = [];
      for (let d = 75; d >= 0; d--) {
        const day = new Date(now.getTime() - d * 864e5);
        if (aIdx === 0 && (day.getDate() === 1 || day.getDate() === 15)) {
          txs.push({ at: day, amount: Math.round(p.salary / 2), desc: 'Pago de nómina', cat: 'ingresos', ch: 'transferencia' });
        }
        for (const [cat, perMonth] of Object.entries(p.spend)) {
          const boost = d <= 30 && cat === Object.keys(p.spend)[0] ? 1.6 : 1;
          if (rand() < (perMonth * boost) / 30 / p.accounts.length) {
            const [min, max] = AMOUNT_RANGE[cat];
            const list = MERCHANTS[cat];
            txs.push({
              at: new Date(day.getTime() + Math.floor(rand() * 12) * 36e5 + 8 * 36e5),
              amount: -Math.round(min + rand() * (max - min)),
              desc: list[Math.floor(rand() * list.length)], cat, ch: rand() < 0.7 ? 'tarjeta_debito' : 'app',
            });
          }
        }
      }
      txs.sort((x, y) => x.at - y.at);
      const net = txs.reduce((s, t) => s + t.amount, 0);
      let bal = a.start - net;
      if (bal < 0) bal = 50000;
      const openingBalance = bal;
      insAcc.run(accId, userId, a.type, a.number, a.alias, 0, created);
      for (const t of txs) {
        if (t.at > now) continue;
        bal += t.amount;
        insMov.run(newId('mov'), accId, t.amount, bal, t.desc, t.cat, t.ch, t.at.toISOString());
      }
      db.prepare('UPDATE accounts SET balance_cents = ? WHERE id = ?').run(bal, accId);
      void openingBalance;
    });
  });

  const insCamp = db.prepare(`INSERT INTO campaigns (id,title,body,cta_label,cta_deeplink,style,segments,priority,active,created_at) VALUES (?,?,?,?,?,?,?,?,1,?)`);
  const ts = now.toISOString();
  insCamp.run('cmp_joven_meta', 'Tu primera meta de ahorro', 'Separa un monto cada quincena y mira cómo crece. Te ayudamos a calcularlo.', 'Simular ahorro', 'microapp://simulador-credito?mode=ahorro', 'accent', '["joven"]', 10, ts);
  insCamp.run('cmp_premium_inv', 'Inversión a plazo con tasa preferencial', 'Por tu relación con nosotros accedes a una tasa preferencial en plazos desde 180 días.', 'Simular inversión', 'microapp://simulador-credito?mode=inversion', 'premium', '["premium"]', 10, ts);
  insCamp.run('cmp_clasico_credito', 'Crédito de consumo 100% digital', 'Conoce tu cuota en segundos y sin ir a una agencia.', 'Simular crédito', 'microapp://simulador-credito', 'accent', '["clasico"]', 10, ts);
  insCamp.run('cmp_all_seguridad', 'Activa las notificaciones', 'Te avisamos al instante de cada movimiento en tus cuentas.', 'Configurar', '/settings', 'info', '[]', 1, ts);

  const insNotif = db.prepare('INSERT INTO notifications (id,user_id,title,body,deeplink,created_at) VALUES (?,?,?,?,?,?)');
  for (const p of PERSONAS) {
    insNotif.run(newId('ntf'), `usr_${p.key}`, '¡Bienvenido a Kinti!', 'Tu banca digital ya está lista. Explora tus cuentas y personaliza tu inicio.', '/home', new Date(now.getTime() - 3 * 864e5).toISOString());
  }
}

export const DEMO_USERS = PERSONAS.map((p) => ({ email: p.email, cedula: p.cedula, accounts: p.accounts.map((a) => a.number) }));
