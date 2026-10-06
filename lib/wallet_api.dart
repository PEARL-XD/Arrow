import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const walletUrl = String.fromEnvironment('ARROW_BACKEND_URL');
const storeEnvironment = String.fromEnvironment(
  'ARROW_STORE_ENVIRONMENT',
  defaultValue: 'sandbox',
);
const purchasesEnabled = bool.fromEnvironment(
  'ARROW_PURCHASES_ENABLED',
  defaultValue: false,
);

class WalletApiException implements Exception {
  WalletApiException(this.code);
  final String code;
}

class WalletApi {
  WalletApi({
    required this.baseUrl,
    http.Client? client,
    FlutterSecureStorage? storage,
  }) : client = client ?? http.Client(),
       storage = storage ?? const FlutterSecureStorage();
  final String baseUrl;
  final http.Client client;
  final FlutterSecureStorage storage;
  String? token;
  String? accountId;
  Future<void>? _connecting;
  String get storageKey =>
      'arrow_wallet_${Uri.encodeComponent(baseUrl)}_$storeEnvironment';
  bool get configured {
    final uri = Uri.tryParse(baseUrl);
    return uri != null &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty &&
        (uri.scheme == 'https' ||
            (kDebugMode &&
                uri.scheme == 'http' &&
                ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host)));
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (!configured) throw WalletApiException('backend_not_configured');
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');
    final req = http.Request(method, uri)..followRedirects = false;
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await client.send(req).timeout(const Duration(seconds: 25)),
    ).timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String code = 'wallet_unavailable';
      try {
        code = (jsonDecode(response.body) as Map)['error'] as String? ?? code;
      } catch (_) {
        /* Never expose upstream bodies. */
      }
      throw WalletApiException(code);
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<void> connect() =>
      _connecting ??= _connect().whenComplete(() => _connecting = null);
  Future<void> _connect() async {
    final config = await request('GET', '/v1/config');
    if (config['environment'] != storeEnvironment) {
      throw WalletApiException('wrong_store_environment');
    }
    token ??= await storage.read(key: storageKey);
    if (token == null) {
      final account = await request('POST', '/v1/accounts');
      final createdToken = account['token'] as String;
      // Do not enable checkout before the credential is durably stored.
      await storage.write(key: storageKey, value: createdToken);
      if (await storage.read(key: storageKey) != createdToken) {
        throw WalletApiException('credential_storage_failed');
      }
      token = createdToken;
    }
    final wallet = await request('GET', '/v1/wallet');
    accountId = wallet['id'] as String;
  }

  Future<void> recover(String recoveryToken) async {
    final config = await request('GET', '/v1/config');
    if (config['environment'] != storeEnvironment) {
      throw WalletApiException('wrong_store_environment');
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(recoveryToken)) {
      throw WalletApiException('invalid_recovery_key');
    }
    final old = token;
    try {
      token = recoveryToken;
      final wallet = await request('GET', '/v1/wallet');
      await storage.write(key: storageKey, value: recoveryToken);
      accountId = wallet['id'] as String;
    } catch (_) {
      token = old;
      rethrow;
    }
  }
}
