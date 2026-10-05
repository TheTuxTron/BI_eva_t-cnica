import { newId } from '../lib/crypto.js';

/**
 * Notificaciones: siempre se persisten en la bandeja (fuente de verdad, consultable por la app
 * aunque el push falle) y, si hay credenciales de Firebase, se envían por FCM.
 */
export async function createPushService({ db, config, logger }) {
  let messaging = null;
  if (config.firebaseServiceAccount) {
    try {
      const admin = (await import('firebase-admin')).default;
      const cred = JSON.parse(config.firebaseServiceAccount);
      const app = admin.apps.length ? admin.app() : admin.initializeApp({ credential: admin.credential.cert(cred) });
      messaging = app.messaging();
      logger.info('fcm_enabled');
    } catch (e) {
      logger.warn({ err: e.message }, 'fcm_init_failed_falling_back_to_inbox');
    }
  }

  async function notify(userId, { title, body, deeplink = null }) {
    const id = newId('ntf');
    const createdAt = new Date().toISOString();
    db.prepare('INSERT INTO notifications (id,user_id,title,body,deeplink,created_at) VALUES (?,?,?,?,?,?)').run(id, userId, title, body, deeplink, createdAt);
    let delivered = 0;
    if (messaging) {
      const tokens = db.prepare('SELECT token FROM devices WHERE user_id = ?').all(userId).map((r) => r.token);
      if (tokens.length) {
        try {
          const r = await messaging.sendEachForMulticast({ tokens, notification: { title, body }, data: { notificationId: id, deeplink: deeplink ?? '' } });
          delivered = r.successCount;
          r.responses.forEach((resp, i) => {
            const code = resp.error?.code ?? '';
            if (code.includes('registration-token-not-registered') || code.includes('invalid-registration-token')) {
              db.prepare('DELETE FROM devices WHERE token = ?').run(tokens[i]);
            }
          });
        } catch (e) {
          logger.warn({ err: e.message }, 'fcm_send_failed');
        }
      }
    }
    return { id, createdAt, delivered, channel: messaging ? 'fcm+inbox' : 'inbox' };
  }

  return { notify, fcmEnabled: () => Boolean(messaging) };
}
