import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinti/app/shell_page.dart';
import 'package:kinti/core/connectivity/connectivity_cubit.dart';
import 'package:kinti/core/network/network_health.dart';

void main() {
  testWidgets('muestra sin conexión, conexión inestable y recuperación', (tester) async {
    final links = StreamController<List<ConnectivityResult>>();
    final health = NetworkHealth();
    final cubit = ConnectivityCubit(health: health, changes: links.stream);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const Align(alignment: Alignment.bottomCenter, child: ConnectivityBanner()),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('connectivity_banner')), findsNothing);

    links.add([ConnectivityResult.none]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Sin conexión'), findsOneWidget);

    links.add([ConnectivityResult.wifi]);
    health
      ..onTransientFailure('a')
      ..onTransientFailure('b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Conexión inestable'), findsOneWidget);

    health.onSuccess('c');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Conexión restablecida'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Conexión restablecida'), findsNothing);
    await links.close();
    await cubit.close();
  });
}
