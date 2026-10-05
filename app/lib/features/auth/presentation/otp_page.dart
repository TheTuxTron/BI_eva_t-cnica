import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di.dart';
import '../../../core/observability/telemetry.dart';
import '../../../design_system/tokens.dart';
import '../../../design_system/widgets.dart';
import '../data/auth_repository.dart';
import 'register_cubit.dart';
import 'session_cubit.dart';

class OtpPage extends StatelessWidget {
  const OtpPage({super.key, required this.ticket});
  final RegistrationTicket ticket;
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => OtpCubit(sl<AuthRepository>(), context.read<SessionCubit>(), sl<Telemetry>(), userId: ticket.userId, devOtp: ticket.devOtp),
        child: _OtpView(maskedPhone: ticket.maskedPhone),
      );
}

class _OtpView extends StatefulWidget {
  const _OtpView({required this.maskedPhone});
  final String maskedPhone;
  @override
  State<_OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<_OtpView> {
  final _code = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => context.read<OtpCubit>().tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica tu celular')),
      body: SafeArea(
        child: BlocBuilder<OtpCubit, OtpState>(
          builder: (context, s) => ListView(padding: const EdgeInsets.all(KSpace.lg), children: [
            Text('Ingresa el código de 6 dígitos que enviamos al ${widget.maskedPhone}.', style: t.bodyLarge),
            if (s.devOtp != null) ...[
              const SizedBox(height: KSpace.md),
              KCard(
                child: Row(children: [
                  const Icon(Icons.science_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Modo demo (sin proveedor SMS): tu código es ${s.devOtp}', key: const Key('otp_dev_hint'))),
                  TextButton(onPressed: () => _code.text = s.devOtp!, child: const Text('Usar')),
                ]),
              ),
            ],
            const SizedBox(height: KSpace.lg),
            TextField(
              key: const Key('otp_input'),
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              style: t.headlineMedium?.copyWith(letterSpacing: 12, fontFeatures: const [FontFeature.tabularFigures()]),
              decoration: kInput(context, label: 'Código', error: s.failure?.message),
              onChanged: (v) {
                if (v.length == 6) context.read<OtpCubit>().verify(v);
              },
            ),
            const SizedBox(height: KSpace.lg),
            LoadingButton(label: 'Verificar', loading: s.submitting, onPressed: () => context.read<OtpCubit>().verify(_code.text)),
            const SizedBox(height: KSpace.sm),
            TextButton(
              onPressed: s.resendIn > 0 ? null : () => context.read<OtpCubit>().resend(),
              child: Text(s.resendIn > 0 ? 'Reenviar código en ${s.resendIn}s' : 'Reenviar código'),
            ),
          ]),
        ),
      ),
    );
  }
}
