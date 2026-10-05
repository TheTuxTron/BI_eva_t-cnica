import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/tokens.dart';
import '../../../design_system/widgets.dart';

/// Primer contacto: explica la propuesta de valor y lleva a abrir cuenta o ingresar.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _page = PageController();
  int _index = 0;

  static const _slides = [
    (
      Icons.phone_iphone_rounded,
      'Tu banco, sin filas',
      'Abre tu cuenta en minutos con tu cédula. Sin agencias y sin papeles.',
    ),
    (Icons.tune_rounded, 'Hecho a tu medida', 'Tu inicio se adapta a lo que más usas y a tus metas.'),
    (Icons.hub_rounded, 'Todo en un lugar', 'Simuladores y servicios de aliados dentro de la misma app.'),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const KintiLogo(),
              Expanded(
                child: PageView.builder(
                  controller: _page,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) {
                    final (icon, title, body) = _slides[i];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(icon, size: 48, color: scheme.primary),
                        ),
                        const SizedBox(height: KSpace.xl),
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                          ),
                        ),
                        const SizedBox(height: KSpace.sm),
                        Text(body, style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    );
                  },
                ),
              ),
              Semantics(
                label: 'Paso ${_index + 1} de ${_slides.length}',
                child: Row(
                  children: [
                    for (var i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: KMotion.fast,
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _index ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _index ? scheme.primary : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: KSpace.lg),
              FilledButton(
                key: const Key('welcome_register'),
                onPressed: () => context.push('/register'),
                child: const Text('Abrir mi cuenta'),
              ),
              const SizedBox(height: KSpace.sm),
              OutlinedButton(
                key: const Key('welcome_login'),
                onPressed: () => context.push('/login'),
                child: const Text('Ya tengo cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
