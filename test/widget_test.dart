import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jastipgo/app.dart';
import 'package:jastipgo/data.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Login and registration validate before contacting server', (
    tester,
  ) async {
    var calls = 0;
    final session = Session(
      client: MockClient((request) async {
        calls++;
        return http.Response('{}', 500);
      }),
    );
    await tester.pumpWidget(JasTipGo(session: session));
    expect(find.text('JasTipGo'), findsOneWidget);
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan email yang valid'), findsOneWidget);
    expect(calls, 0);
    await tester.ensureVisible(find.text('Belum punya akun? Daftar'));
    await tester.tap(find.text('Belum punya akun? Daftar'));
    await tester.pumpAndSettle();
    expect(find.text('Nama lengkap'), findsOneWidget);
    expect(find.text('Buat akun'), findsOneWidget);
  });

  test(
    'Session persists identity and role, restores auto-login, clears on 401',
    () async {
      final session = Session(
        client: MockClient((request) async {
          final data = jsonDecode(request.body);
          if (data['action'] == 'login') {
            return http.Response(
              jsonEncode({
                'result': 'success',
                'data': {
                  'token': 'abc',
                  'user': {
                    'id': 9,
                    'name': 'Test',
                    'email': 'test@example.com',
                    'balance': 0,
                  },
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({'result': 'error', 'message': 'expired'}),
            401,
          );
        }),
      );
      await session.authenticate('login', {
        'email': 'test@example.com',
        'password': 'password',
      });
      await session.switchRole();
      final restored = Session();
      await restored.restore();
      expect(restored.userId, 9);
      expect(restored.isSeller, isTrue);
      expect(restored.token, 'abc');
      await expectLater(session.request('me'), throwsA(isA<ApiException>()));
      expect(session.user, isNull);
      expect((await SharedPreferences.getInstance()).getInt('user_id'), isNull);
      restored.dispose();
      session.dispose();
    },
  );

  testWidgets('Catalog displays data and survives narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = Session(
      client: MockClient((request) async {
        final action = jsonDecode(request.body)['action'];
        final data = action == 'categories'
            ? [
                {'id': 1, 'name': 'Kuliner'},
              ]
            : [
                {
                  'id': 1,
                  'name': 'Tokyo Banana',
                  'price': 150000,
                  'stock': 8,
                  'trip_name': 'Tokyo November',
                  'photo': '',
                  'categories': [],
                },
              ];
        return http.Response(
          jsonEncode({'result': 'success', 'data': data}),
          200,
        );
      }),
    )..user = {'id': 1, 'name': 'Henry', 'email': 'henry@example.com'};
    await tester.pumpWidget(JasTipGo(session: session));
    await tester.pumpAndSettle();
    expect(find.text('Tokyo Banana'), findsOneWidget);
    expect(find.text('Stok 8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
