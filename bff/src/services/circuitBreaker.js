/**
 * Circuit breaker simple (closed → open → half-open) para dependencias externas.
 * Evita martillar un servicio caído y permite responder rápido con datos en caché.
 */
export class CircuitBreaker {
  constructor({ failureThreshold = 3, resetTimeoutMs = 30_000, now = () => Date.now() } = {}) {
    this.failureThreshold = failureThreshold;
    this.resetTimeoutMs = resetTimeoutMs;
    this.now = now;
    this.state = 'closed';
    this.failures = 0;
    this.openedAt = 0;
  }

  canRequest() {
    if (this.state === 'open' && this.now() - this.openedAt >= this.resetTimeoutMs) this.state = 'half-open';
    return this.state !== 'open';
  }

  onSuccess() { this.state = 'closed'; this.failures = 0; }

  onFailure() {
    this.failures += 1;
    if (this.state === 'half-open' || this.failures >= this.failureThreshold) {
      this.state = 'open';
      this.openedAt = this.now();
    }
  }

  async exec(fn) {
    if (!this.canRequest()) {
      const e = new Error('circuit_open');
      e.circuitOpen = true;
      throw e;
    }
    try {
      const r = await fn();
      this.onSuccess();
      return r;
    } catch (e) {
      this.onFailure();
      throw e;
    }
  }
}
