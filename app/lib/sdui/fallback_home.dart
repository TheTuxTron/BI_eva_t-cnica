/// Experiencia mínima embebida en la app: se usa si el servicio de personalización
/// no responde y no hay caché. Garantiza que el cliente siempre vea sus cuentas.
const Map<String, dynamic> kFallbackHome = {
  'schemaVersion': 1,
  'screen': 'home',
  'ttlSeconds': 60,
  'theme': {'segment': 'clasico', 'seedColor': '#E46F0A', 'mode': 'system'},
  'sections': [
    {
      'id': 'greeting',
      'type': 'greeting',
      'props': {'title': 'Hola', 'subtitle': 'Tus finanzas, claras y al día.'},
    },
    {
      'id': 'accounts',
      'type': 'account_summary',
      'props': {'showTotal': true, 'balanceVisible': true},
    },
    {
      'id': 'quick_actions',
      'type': 'quick_actions',
      'props': {
        'actions': [
          {'id': 'transfer', 'label': 'Transferir', 'icon': 'swap_horiz', 'deeplink': '/transfer'},
          {'id': 'movements', 'label': 'Movimientos', 'icon': 'receipt_long', 'deeplink': '/accounts'},
        ],
      },
    },
  ],
  'meta': {
    'segment': 'clasico',
    'reasons': ['Experiencia básica: personalización no disponible'],
  },
};
