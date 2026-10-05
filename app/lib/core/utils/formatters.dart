/// Formateo determinístico (sin depender de datos de locale en runtime).
class Money {
  static String format(int cents, {bool signed = false, String currency = 'USD'}) {
    final neg = cents < 0;
    final abs = cents.abs();
    final units = (abs ~/ 100).toString();
    final dec = (abs % 100).toString().padLeft(2, '0');
    final grouped = StringBuffer();
    for (var i = 0; i < units.length; i++) {
      if (i > 0 && (units.length - i) % 3 == 0) grouped.write('.');
      grouped.write(units[i]);
    }
    final sign = neg ? '-' : (signed && cents > 0 ? '+' : '');
    return '$sign\$$grouped,$dec';
  }

  /// Texto para lectores de pantalla: "1.234 dólares con 56 centavos".
  static String spoken(int cents) {
    final abs = cents.abs();
    final prefix = cents < 0 ? 'menos ' : '';
    return '$prefix${abs ~/ 100} dólares con ${abs % 100} centavos';
  }

  /// "12.50" | "12,50" → 1250; null si es inválido.
  static int? parseToCents(String input) {
    final s = input.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s)) return null;
    final parts = s.split('.');
    return int.parse(parts[0]) * 100 + int.parse((parts.length > 1 ? parts[1] : '').padRight(2, '0'));
  }

  static String toApi(int cents) => '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
}

class Dates {
  static const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  static String short(DateTime d) {
    final l = d.toLocal();
    return '${l.day} ${_months[l.month - 1]} · ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  static String dayHeader(DateTime d, {DateTime? now}) {
    final l = d.toLocal();
    final n = (now ?? DateTime.now()).toLocal();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(l.year, l.month, l.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return '${l.day} de ${_months[l.month - 1]}${l.year != n.year ? ' ${l.year}' : ''}';
  }

  static String ago(DateTime d, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(d);
    if (diff.inSeconds < 60) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }
}

/// Validación local de cédula ecuatoriana (feedback inmediato; el BFF vuelve a validar).
class Cedula {
  static bool isValid(String v) {
    if (!RegExp(r'^\d{10}$').hasMatch(v)) return false;
    final province = int.parse(v.substring(0, 2));
    if (!((province >= 1 && province <= 24) || province == 30)) return false;
    if (int.parse(v[2]) >= 6) return false;
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      var d = int.parse(v[i]) * (i.isEven ? 2 : 1);
      if (d > 9) d -= 9;
      sum += d;
    }
    return (10 - sum % 10) % 10 == int.parse(v[9]);
  }
}

/// Primer elemento que cumple [test] o null (independiente de la versión del SDK).
T? firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final i in items) {
    if (test(i)) return i;
  }
  return null;
}
