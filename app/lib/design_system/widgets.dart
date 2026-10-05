import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/network/failures.dart';
import '../core/utils/formatters.dart';
import 'tokens.dart';

/// Monto con cifras tabulares, color semántico y lectura accesible.
class AmountText extends StatelessWidget {
  const AmountText(this.cents, {super.key, this.style, this.signed = false, this.colored = false, this.hidden = false});
  final int cents;
  final TextStyle? style;
  final bool signed;
  final bool colored;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? Theme.of(context).textTheme.titleMedium)!;
    final color = colored ? (cents < 0 ? KColors.negative : KColors.positive) : base.color;
    return Semantics(
      label: hidden ? 'Saldo oculto' : Money.spoken(cents),
      excludeSemantics: true,
      child: Text(
        hidden ? '\$ • • • •' : Money.format(cents, signed: signed),
        style: base.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

/// Bloque de carga que respeta "reducir movimiento" del sistema.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 8});
  final double height;
  final double? width;
  final double radius;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.06 + 0.06 * _c.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// Error con acción de reintento y requestId visible para soporte.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, this.onRetry, this.compact = false});
  final AppFailure failure;
  final VoidCallback? onRetry;
  final bool compact;

  IconData get _icon => switch (failure) {
        NetworkFailure() => Icons.wifi_off_rounded,
        TimeoutFailure() => Icons.hourglass_bottom_rounded,
        ServiceUnavailableFailure() => Icons.cloud_off_rounded,
        _ => Icons.error_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final content = [
      Icon(_icon, size: compact ? 28 : 44, color: Theme.of(context).colorScheme.outline),
      SizedBox(height: compact ? 8 : 12),
      Text(failure.message, textAlign: TextAlign.center, style: compact ? t.bodyMedium : t.titleMedium),
      if (failure.requestId != null && !compact) ...[
        const SizedBox(height: 6),
        SelectableText('Código de soporte: ${failure.requestId!.substring(0, 8)}', style: t.bodySmall),
      ],
      if (kDebugMode && debugDetail(failure) != null) ...[
        const SizedBox(height: 6),
        SelectableText(debugDetail(failure)!, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(fontFamily: 'monospace')),
      ],
      if (onRetry != null && (failure.isTransient || failure is UnknownFailure)) ...[
        SizedBox(height: compact ? 8 : 16),
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44))),
      ],
    ];
    return Padding(
      padding: EdgeInsets.all(compact ? KSpace.md : KSpace.xl),
      child: Column(mainAxisSize: MainAxisSize.min, children: content),
    );
  }
}

/// Indica que el usuario ve datos guardados y desde cuándo.
class StaleNotice extends StatelessWidget {
  const StaleNotice({super.key, required this.updatedAt, this.offline = false, this.onRetry});
  final DateTime? updatedAt;
  final bool offline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final when = updatedAt == null ? '' : ' de ${Dates.ago(updatedAt!)}';
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: KColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(KRadius.chip),
        ),
        child: Row(children: [
          const Icon(Icons.history_rounded, size: 18, color: KColors.warning),
          const SizedBox(width: 8),
          Expanded(child: Text('Mostrando datos guardados$when', style: Theme.of(context).textTheme.bodySmall)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, style: TextButton.styleFrom(minimumSize: const Size(48, 40)), child: const Text('Actualizar')),
        ]),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: KSpace.sm),
        child: Row(children: [
          Expanded(child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium))),
          if (trailing != null) trailing!,
        ]),
      );
}

class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key, required this.label, required this.onPressed, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? Semantics(label: 'Procesando', child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)))
            : Text(label),
      );
}

/// Tarjeta base con borde sutil (evita depender de CardTheme, cuyo tipo cambió entre versiones de Flutter).
class KCard extends StatelessWidget {
  const KCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(KSpace.md), this.color, this.radius = KRadius.card});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: dark ? KColors.darkLine : KColors.line),
    );
    return Material(
      color: color ?? Theme.of(context).colorScheme.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

InputDecoration kInput(BuildContext context, {required String label, String? hint, String? error, Widget? prefix, Widget? suffix, String? helper}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: dark ? KColors.darkLine : KColors.line));
  final focused = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: KBrand.of(context).action, width: 2));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: error,
    helperText: helper,
    prefixIcon: prefix,
    suffixIcon: suffix,
    filled: true,
    fillColor: dark ? KColors.darkSurface : Colors.white,
    border: border,
    enabledBorder: border,
    focusedBorder: focused,
  );
}

/// Marca de la app (kinti = colibrí en kichwa).
class KintiLogo extends StatelessWidget {
  const KintiLogo({super.key, this.size = 32});
  final double size;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Kinti',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: KColors.brandOrange, borderRadius: BorderRadius.circular(size * 0.32)),
          child: Text('k', style: TextStyle(color: KColors.ink, fontWeight: FontWeight.w900, fontSize: size * 0.62, height: 1)),
        ),
        SizedBox(width: size * 0.25),
        ExcludeSemantics(
          child: Text('kinti', style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.75, color: KBrand.of(context).action, letterSpacing: -0.5)),
        ),
      ]),
    );
  }
}

/// Texto de error para formularios: mensaje + (solo en debug) causa técnica.
class FailureText extends StatelessWidget {
  const FailureText(this.failure, {super.key});
  final AppFailure failure;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: Theme.of(context).colorScheme.error);
    final detail = kDebugMode ? debugDetail(failure) : null;
    return Semantics(
      liveRegion: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(failure.message, style: style),
        if (failure.requestId != null) Text('Código de soporte: ${failure.requestId!.substring(0, 8)}', style: Theme.of(context).textTheme.bodySmall),
        if (detail != null) SelectableText(detail, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
      ]),
    );
  }
}

/// Causa técnica legible para depurar (nunca se muestra en release).
String? debugDetail(AppFailure f) => switch (f) {
      NetworkFailure(:final detail) => '[debug] ${f.runtimeType}: ${detail ?? 'sin detalle'}',
      UnknownFailure() => '[debug] ${f.message}',
      ServerFailure(:final code) || ServiceUnavailableFailure(:final code) => '[debug] ${f.runtimeType} $code',
      BusinessFailure(:final code) => '[debug] $code',
      _ => null,
    };
