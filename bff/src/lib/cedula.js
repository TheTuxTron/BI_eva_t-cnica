/**
 * Valida una cédula ecuatoriana (algoritmo módulo 10 del Registro Civil).
 * Provincias 01-24 y 30 (ecuatorianos en el exterior); tercer dígito < 6 para personas naturales.
 */
export function isValidCedula(value) {
  if (typeof value !== 'string' || !/^\d{10}$/.test(value)) return false;
  const province = Number(value.slice(0, 2));
  if (!((province >= 1 && province <= 24) || province === 30)) return false;
  if (Number(value[2]) >= 6) return false;
  return checkDigit(value.slice(0, 9)) === Number(value[9]);
}

export function checkDigit(nineDigits) {
  let sum = 0;
  for (let i = 0; i < 9; i++) {
    let d = Number(nineDigits[i]) * (i % 2 === 0 ? 2 : 1);
    if (d > 9) d -= 9;
    sum += d;
  }
  return (10 - (sum % 10)) % 10;
}

export const buildCedula = (nine) => nine + checkDigit(nine);
