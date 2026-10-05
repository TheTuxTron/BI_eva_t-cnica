/** Convierte "123.45" | 123.45 a centavos enteros sin errores de coma flotante. */
export function toCents(amount) {
  const s = String(amount).trim();
  if (!/^\d+(\.\d{1,2})?$/.test(s)) return NaN;
  const [int, dec = ''] = s.split('.');
  return Number(int) * 100 + Number(dec.padEnd(2, '0'));
}
export const fromCents = (c) => (c / 100).toFixed(2);
export const fmtUsd = (c) =>
  `$${(c / 100).toLocaleString('es-EC', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
