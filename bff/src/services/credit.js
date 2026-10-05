/** Tabla de amortización sistema francés (cuota fija). */
export function frenchAmortization({ amountCents, months, annualRate }) {
  const i = annualRate / 12;
  const payment = i === 0 ? amountCents / months : (amountCents * i) / (1 - (1 + i) ** -months);
  let balance = amountCents;
  const schedule = [];
  for (let n = 1; n <= months; n++) {
    const interest = balance * i;
    const principal = payment - interest;
    balance = Math.max(0, balance - principal);
    schedule.push({ n, paymentCents: Math.round(payment), interestCents: Math.round(interest), principalCents: Math.round(principal), balanceCents: Math.round(balance) });
  }
  const total = Math.round(payment * months);
  return { paymentCents: Math.round(payment), totalCents: total, totalInterestCents: total - amountCents, schedule };
}

export const RATES = {
  credito: { joven: 0.1599, clasico: 0.1550, premium: 0.1150 },
  inversion: { joven: 0.0650, clasico: 0.0700, premium: 0.0825 },
  ahorro: { joven: 0.0400, clasico: 0.0350, premium: 0.0350 },
};

/** Proyección de ahorro mensual con interés compuesto. */
export function savingsProjection({ monthlyCents, months, annualRate }) {
  const i = annualRate / 12;
  let bal = 0;
  const points = [];
  for (let n = 1; n <= months; n++) {
    bal = bal * (1 + i) + monthlyCents;
    points.push({ n, balanceCents: Math.round(bal) });
  }
  return { finalCents: Math.round(bal), contributedCents: monthlyCents * months, interestCents: Math.round(bal) - monthlyCents * months, points };
}
