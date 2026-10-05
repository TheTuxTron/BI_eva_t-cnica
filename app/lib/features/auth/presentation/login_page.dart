import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/env.dart';
import '../../../core/network/failures.dart';
import '../../../core/observability/telemetry.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets.dart';
import '../data/auth_repository.dart';
import 'login_cubit.dart';
import 'session_cubit.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => LoginCubit(sl<AuthRepository>(), context.read<SessionCubit>(), sl<Telemetry>()),
    child: const LoginView(),
  );
}

class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      context.read<LoginCubit>().submit(_user.text, _pass.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = context.select((SessionCubit c) => c.state.expired);
    final showDemo = sl.isRegistered<AppEnv>() && sl<AppEnv>().enableDevTools;
    return Scaffold(
      appBar: AppBar(title: const Text('Ingresar')),
      body: SafeArea(
        child: BlocBuilder<LoginCubit, LoginState>(
          builder:
              (context, state) => Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(KSpace.lg),
                  children: [
                    if (expired)
                      const Padding(
                        padding: EdgeInsets.only(bottom: KSpace.md),
                        child: Text('Tu sesión terminó por seguridad. Ingresa nuevamente.'),
                      ),
                    TextFormField(
                      key: const Key('login_username'),
                      controller: _user,
                      decoration: kInput(context, label: 'Correo o cédula', prefix: const Icon(Icons.person_outline)),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      validator: (v) => (v == null || v.trim().length < 3) ? 'Ingresa tu correo o cédula' : null,
                    ),
                    const SizedBox(height: KSpace.md),
                    TextFormField(
                      key: const Key('login_password'),
                      controller: _pass,
                      obscureText: _obscure,
                      decoration: kInput(
                        context,
                        label: 'Contraseña',
                        prefix: const Icon(Icons.lock_outline),
                        suffix: IconButton(
                          tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                    ),
                    if (state.failure != null) ...[
                      const SizedBox(height: KSpace.md),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          state.failure!.message,
                          key: const Key('login_error'),
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: KSpace.lg),
                    LoadingButton(
                      key: const Key('login_submit'),
                      label: 'Ingresar',
                      loading: state.submitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: KSpace.sm),
                    TextButton(
                      onPressed: () => context.pushReplacement('/register'),
                      child: const Text('¿No tienes cuenta? Ábrela aquí'),
                    ),
                    if (showDemo) ...[
                      const SizedBox(height: KSpace.lg),
                      Text('Usuarios de demostración', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: KSpace.sm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (label, email) in const [
                            ('Ana · joven', 'ana@kinti.ec'),
                            ('Carlos · premium', 'carlos@kinti.ec'),
                            ('María · clásico', 'maria@kinti.ec'),
                          ])
                            ActionChip(
                              label: Text(label),
                              onPressed: () {
                                _user.text = email;
                                _pass.text = 'Kinti2026!';
                              },
                            ),
                        ],
                      ),
                    ],
                    if (state.failure is NetworkFailure || state.failure is TimeoutFailure)
                      const Padding(
                        padding: EdgeInsets.only(top: KSpace.md),
                        child: Text('Necesitas conexión para ingresar por primera vez en este dispositivo.'),
                      ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}
