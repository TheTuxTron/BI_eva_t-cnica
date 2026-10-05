import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinti/app/di.dart';
import 'package:kinti/core/network/failures.dart';
import 'package:kinti/features/auth/presentation/login_cubit.dart';
import 'package:kinti/features/auth/presentation/login_page.dart';
import 'package:kinti/features/auth/presentation/session_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginCubit extends MockCubit<LoginState> implements LoginCubit {}

class MockSessionCubit extends MockCubit<SessionState> implements SessionCubit {}

void main() {
  late MockLoginCubit login;
  late MockSessionCubit session;

  setUp(() async {
    await sl.reset();
    login = MockLoginCubit();
    session = MockSessionCubit();
    when(() => session.state).thenReturn(const SessionState.unauthenticated());
    when(() => login.state).thenReturn(const LoginState());
    when(() => login.submit(any(), any())).thenAnswer((_) async {});
  });

  Widget app() => MaterialApp(
    home: MultiBlocProvider(
      providers: [BlocProvider<SessionCubit>.value(value: session), BlocProvider<LoginCubit>.value(value: login)],
      child: const LoginView(),
    ),
  );

  testWidgets('valida campos vacíos sin llamar al servidor', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    expect(find.text('Ingresa tu correo o cédula'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    verifyNever(() => login.submit(any(), any()));
  });

  testWidgets('envía las credenciales ingresadas', (tester) async {
    await tester.pumpWidget(app());
    await tester.enterText(find.byKey(const Key('login_username')), 'ana@kinti.ec');
    await tester.enterText(find.byKey(const Key('login_password')), 'Kinti2026!');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    verify(() => login.submit('ana@kinti.ec', 'Kinti2026!')).called(1);
  });

  testWidgets('muestra el error del servidor y el indicador de carga', (tester) async {
    when(
      () => login.state,
    ).thenReturn(const LoginState(failure: UnauthorizedFailure('Usuario o contraseña incorrectos')));
    await tester.pumpWidget(app());
    expect(find.byKey(const Key('login_error')), findsOneWidget);

    when(() => login.state).thenReturn(const LoginState(submitting: true));
    await tester.pumpWidget(app());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('avisa cuando la sesión expiró por seguridad', (tester) async {
    when(() => session.state).thenReturn(const SessionState.unauthenticated(expired: true));
    await tester.pumpWidget(app());
    expect(find.textContaining('Tu sesión terminó por seguridad'), findsOneWidget);
  });
}
