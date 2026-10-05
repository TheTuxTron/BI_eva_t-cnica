import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../core/observability/telemetry.dart';
import '../../../core/utils/formatters.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets.dart';
import '../data/auth_repository.dart';
import 'register_cubit.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => RegisterCubit(sl<AuthRepository>(), sl<Telemetry>()),
        child: const RegisterView(),
      );
}

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});
  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _forms = List.generate(3, (_) => GlobalKey<FormState>());
  final _cedula = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  DateTime? _birth;
  bool _terms = false;

  static const _titles = ['Tus datos', 'Contacto', 'Seguridad'];

  @override
  void dispose() {
    for (final c in [_cedula, _first, _last, _email, _phone, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) setState(() => _birth = picked);
  }

  void _continue(RegisterState s) {
    final ok = _forms[s.step].currentState?.validate() ?? false;
    if (!ok) return;
    if (s.step == 0 && _birth == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona tu fecha de nacimiento')));
      return;
    }
    if (s.step < 2) {
      context.read<RegisterCubit>().next();
      return;
    }
    context.read<RegisterCubit>().submit(RegistrationData(
          cedula: _cedula.text.trim(),
          firstName: _first.text.trim(),
          lastName: _last.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          birthDate: _birth!,
          password: _pass.text,
          acceptTerms: _terms,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterCubit, RegisterState>(
      listenWhen: (a, b) => a.ticket != b.ticket && b.ticket != null,
      listener: (context, s) => context.pushReplacement('/register/otp', extra: s.ticket),
      builder: (context, s) => PopScope(
        canPop: s.step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.read<RegisterCubit>().back();
        },
        child: Scaffold(
          appBar: AppBar(title: Text('Abre tu cuenta · ${_titles[s.step]}')),
          body: SafeArea(
            child: Column(children: [
              Semantics(
                label: 'Paso ${s.step + 1} de 3',
                child: LinearProgressIndicator(value: (s.step + 1) / 3, minHeight: 3),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.all(KSpace.lg), children: [
                  IndexedStack(index: s.step, children: [_identity(s), _contact(s), _security(s)]),
                  if (s.failure != null && s.fieldErrors.isEmpty) ...[
                    const SizedBox(height: KSpace.md),
                    FailureText(s.failure!, key: const Key('register_error')),
                  ],
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(KSpace.lg),
                child: LoadingButton(
                  key: const Key('register_continue'),
                  label: s.step < 2 ? 'Continuar' : 'Crear mi cuenta',
                  loading: s.submitting,
                  onPressed: () => _continue(s),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _identity(RegisterState s) => Form(
        key: _forms[0],
        child: Column(children: [
          TextFormField(
            key: const Key('reg_cedula'),
            controller: _cedula,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            decoration: kInput(context, label: 'Cédula', error: s.fieldErrors['cedula'], prefix: const Icon(Icons.badge_outlined)),
            validator: (v) => Cedula.isValid(v ?? '') ? null : 'Cédula ecuatoriana inválida',
          ),
          const SizedBox(height: KSpace.md),
          TextFormField(
            controller: _first,
            textCapitalization: TextCapitalization.words,
            decoration: kInput(context, label: 'Nombres', error: s.fieldErrors['firstName']),
            validator: (v) => (v ?? '').trim().length < 2 ? 'Ingresa tus nombres' : null,
          ),
          const SizedBox(height: KSpace.md),
          TextFormField(
            controller: _last,
            textCapitalization: TextCapitalization.words,
            decoration: kInput(context, label: 'Apellidos', error: s.fieldErrors['lastName']),
            validator: (v) => (v ?? '').trim().length < 2 ? 'Ingresa tus apellidos' : null,
          ),
          const SizedBox(height: KSpace.md),
          KCard(
            onTap: _pickBirth,
            child: Row(children: [
              const Icon(Icons.cake_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_birth == null ? 'Fecha de nacimiento' : '${_birth!.day}/${_birth!.month}/${_birth!.year}'),
              ),
              const Icon(Icons.edit_calendar_outlined),
            ]),
          ),
        ]),
      );

  Widget _contact(RegisterState s) => Form(
        key: _forms[1],
        child: Column(children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: kInput(context, label: 'Correo electrónico', error: s.fieldErrors['email'], prefix: const Icon(Icons.alternate_email)),
            validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Correo inválido',
          ),
          const SizedBox(height: KSpace.md),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            decoration: kInput(context, label: 'Celular', hint: '09XXXXXXXX', error: s.fieldErrors['phone'], prefix: const Icon(Icons.smartphone), helper: 'Te enviaremos un código de verificación'),
            validator: (v) => RegExp(r'^09\d{8}$').hasMatch(v ?? '') ? null : 'Celular inválido',
          ),
        ]),
      );

  Widget _security(RegisterState s) {
    final p = _pass.text;
    final rules = [('Mínimo 8 caracteres', p.length >= 8), ('Una mayúscula', RegExp('[A-Z]').hasMatch(p)), ('Un número', RegExp('[0-9]').hasMatch(p))];
    return Form(
      key: _forms[2],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextFormField(
          controller: _pass,
          obscureText: true,
          onChanged: (_) => setState(() {}),
          autofillHints: const [AutofillHints.newPassword],
          decoration: kInput(context, label: 'Crea tu contraseña', error: s.fieldErrors['password'], prefix: const Icon(Icons.lock_outline)),
          validator: (_) => rules.every((r) => r.$2) ? null : 'La contraseña no cumple los requisitos',
        ),
        const SizedBox(height: KSpace.sm),
        for (final (label, ok) in rules)
          Semantics(
            label: '$label: ${ok ? 'cumple' : 'pendiente'}',
            child: Row(children: [
              Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: ok ? KColors.positive : Theme.of(context).colorScheme.outline),
              const SizedBox(width: 8),
              ExcludeSemantics(child: Text(label)),
            ]),
          ),
        const SizedBox(height: KSpace.md),
        FormField<bool>(
          validator: (_) => _terms ? null : 'Debes aceptar los términos',
          builder: (field) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _terms,
              onChanged: (v) => setState(() => _terms = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Acepto los términos y el tratamiento de mis datos personales (LOPDP)'),
            ),
            if (field.hasError) Text(field.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}
