import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_out/wallet_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'concurrent startup creates only one wallet and reads back its durable key',
    () async {
      var creates = 0;
      final key = 'a' * 43;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/config') {
          return http.Response('{"environment":"sandbox"}', 200);
        }
        if (request.url.path == '/v1/accounts') {
          creates++;
          return http.Response(
            jsonEncode({'id': 'wallet-id', 'token': key}),
            201,
          );
        }
        expect(request.headers['Authorization'], 'Bearer $key');
        return http.Response('{"id":"wallet-id","balance":0}', 200);
      });
      final api = WalletApi(
        baseUrl: 'https://wallet.example.test',
        client: client,
      );
      await Future.wait([api.connect(), api.connect(), api.connect()]);
      expect(creates, 1);
      expect(api.accountId, 'wallet-id');
      final reopened = WalletApi(baseUrl: api.baseUrl, client: client);
      await reopened.connect();
      expect(creates, 1);
      expect(reopened.token, key);
    },
  );
  test('wrong environment is rejected before creating an account', () async {
    var calls = 0;
    final api = WalletApi(
      baseUrl: 'https://wallet.example.test',
      client: MockClient((_) async {
        calls++;
        return http.Response('{"environment":"production"}', 200);
      }),
    );
    await expectLater(api.connect(), throwsA(isA<WalletApiException>()));
    expect(calls, 1);
    expect(api.token, isNull);
  });
  test(
    'unsafe URL and embedded credentials cannot receive wallet requests',
    () {
      for (final url in [
        '',
        'http://public.example.test',
        'https://user:secret@example.test',
        'https://example.test?key=secret',
      ]) {
        expect(WalletApi(baseUrl: url).configured, false);
      }
      expect(
        WalletApi(baseUrl: 'https://wallet.example.test').configured,
        true,
      );
    },
  );
  test(
    'a failed recovery does not replace the current wallet credential',
    () async {
      var calls = 0;
      final api = WalletApi(
        baseUrl: 'https://wallet.example.test',
        client: MockClient((_) async {
          calls++;
          return calls == 1
              ? http.Response('{"environment":"sandbox"}', 200)
              : http.Response('{"error":"unauthorized"}', 401);
        }),
      )..token = 'a' * 43;
      await expectLater(
        api.recover('b' * 43),
        throwsA(isA<WalletApiException>()),
      );
      expect(api.token, 'a' * 43);
    },
  );
  test(
    'redirects are rejected instead of forwarding wallet credentials',
    () async {
      var calls = 0;
      final api = WalletApi(
        baseUrl: 'https://wallet.example.test',
        client: MockClient((request) async {
          calls++;
          expect(request.followRedirects, false);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://attacker.example.test'},
          );
        }),
      )..token = 'a' * 43;
      await expectLater(
        api.request('GET', '/v1/wallet'),
        throwsA(isA<WalletApiException>()),
      );
      expect(calls, 1);
    },
  );
}
