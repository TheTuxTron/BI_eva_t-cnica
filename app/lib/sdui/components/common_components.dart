import 'package:flutter/material.dart';

import '../../app/deep_links.dart';
import '../../app/di.dart';
import '../../core/observability/telemetry.dart';
import '../../design_system/tokens.dart';
import '../../design_system/widgets.dart';
import '../sdui_models.dart';
import '../sdui_registry.dart';

/// Íconos permitidos para SDUI (lista blanca: el servidor no envía assets arbitrarios).
const Map<String, IconData> kSduiIcons = {
  'swap_horiz': Icons.swap_horiz_rounded,
  'receipt_long': Icons.receipt_long_rounded,
  'calculate': Icons.calculate_rounded,
  'trending_up': Icons.trending_up_rounded,
  'savings': Icons.savings_rounded,
  'auto_awesome': Icons.auto_awesome_rounded,
  'pie_chart': Icons.pie_chart_rounded,
  'notifications': Icons.notifications_rounded,
  'shield': Icons.shield_rounded,
};

IconData sduiIcon(String? name) => kSduiIcons[name] ?? Icons.circle_outlined;

void registerCommonComponents(SduiRegistry r) {
  r.register('greeting', (c, s) => GreetingComponent(section: s));
  r.register('quick_actions', (c, s) => QuickActionsComponent(section: s));
  r.register('banner', (c, s) => BannerComponent(section: s));
  r.register('insight_card', (c, s) => InsightComponent(section: s));
  r.register('text', (c, s) => Text(s.str('text') ?? '', style: Theme.of(c).textTheme.bodyMedium));
}

void _open(BuildContext context, String? link, String source) {
  if (link == null) return;
  sl<DeepLinks>().open(context, link, source: source);
}

class GreetingComponent extends StatelessWidget {
  const GreetingComponent({super.key, required this.section});
  final SduiSection section;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(header: true, child: Text(section.str('title') ?? 'Hola', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
      if (section.str('subtitle') != null) ...[
        const SizedBox(height: 4),
        Text(section.str('subtitle')!, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    ]);
  }
}

class QuickActionsComponent extends StatelessWidget {
  const QuickActionsComponent({super.key, required this.section});
  final SduiSection section;
  @override
  Widget build(BuildContext context) {
    final actions = section.list('actions').take(4).toList();
    final scheme = Theme.of(context).colorScheme;
    final brand = KBrand.of(context);
    return Row(
      children: [
        for (final a in actions)
          Expanded(
            child: Semantics(
              button: true,
              label: a['label'] as String?,
              child: InkWell(
                borderRadius: BorderRadius.circular(KRadius.card),
                onTap: () {
                  sl<Telemetry>().event('action_${a['id']}');
                  _open(context, a['deeplink'] as String?, 'quick_action');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpace.sm),
                  child: Column(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
                      child: Icon(sduiIcon(a['icon'] as String?), color: brand.action),
                    ),
                    const SizedBox(height: 6),
                    ExcludeSemantics(
                      child: Text(a['label'] as String? ?? '', textAlign: TextAlign.center, maxLines: 2, style: Theme.of(context).textTheme.labelMedium),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class BannerComponent extends StatelessWidget {
  const BannerComponent({super.key, required this.section});
  final SduiSection section;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = section.str('style') ?? 'accent';
    final (bg, fg) = switch (style) {
      'premium' => (KColors.brandCafe, Colors.white),
      'info' => (scheme.surfaceContainerHighest, scheme.onSurface),
      _ => (scheme.primary, scheme.onPrimary),
    };
    final cta = section.map('cta');
    return KCard(
      color: bg,
      onTap: cta == null ? null : () => _open(context, cta['deeplink'] as String?, 'banner:${section.id}'),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(section.str('title') ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg)),
            const SizedBox(height: 4),
            Text(section.str('body') ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.88))),
            if (cta != null) ...[
              const SizedBox(height: 10),
              Text('${cta['label']}', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: style == 'premium' ? KColors.brandPeach : fg, fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
        if (cta != null) Icon(Icons.chevron_right_rounded, color: fg),
      ]),
    );
  }
}

class InsightComponent extends StatelessWidget {
  const InsightComponent({super.key, required this.section});
  final SduiSection section;
  @override
  Widget build(BuildContext context) {
    final tone = section.str('tone');
    final color = switch (tone) { 'warning' => KColors.warning, 'positive' => KColors.positive, _ => KBrand.of(context).action };
    final compact = section.str('variant') == 'compact';
    return KCard(
      onTap: () {
        sl<Telemetry>().event('action_insight');
        _open(context, section.str('deeplink'), 'insight');
      },
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(sduiIcon(section.str('icon')), color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(section.str('title') ?? '', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(section.str('body') ?? '', style: Theme.of(context).textTheme.bodySmall),
            ],
          ]),
        ),
      ]),
    );
  }
}
