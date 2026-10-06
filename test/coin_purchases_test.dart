import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_out/coin_purchases.dart';
import 'package:path_out/game_controller.dart';
import 'package:path_out/puzzle.dart';
import 'package:path_out/wallet_api.dart';
import 'package:path_out/reward_options.dart';
import 'package:path_out/shop_screen.dart';

class FakeWalletApi extends WalletApi {
  FakeWalletApi() : super(baseUrl: 'https://wallet.example.test');
  int paid = 1500, verifyCalls = 0, spendCalls = 0;
  bool offline = false, loseSpendResponse = false, loseVerifyResponse = false;
  final receipts = <String>{};
  final deliveries = <String, Map<String, dynamic>>{};
  final spent = <String>{};
  final owned = <String>{};
  Map<String, dynamic> get wallet => {
    'id': 'account',
    'balance': paid,
    'entitlements': owned.toList(),
    'deliveries': deliveries.values.toList(),
  };
  @override
  Future<void> connect() async {
    accountId = 'account';
    token = 'key';
  }

  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    if (offline) throw const SocketException('offline');
    if (path == '/v1/config') {
      return {'environment': 'sandbox', 'android': true, 'ios': true};
    }
    if (path == '/v1/wallet') return wallet;
    if (path == '/v1/purchases/verify') {
      verifyCalls++;
      if (receipts.add(body!['transactionId'] as String)) paid += 1500;
      if (loseVerifyResponse) {
        loseVerifyResponse = false;
        throw const SocketException('lost');
      }
      return wallet;
    }
    if (path == '/v1/spends') {
      spendCalls++;
      if (spent.add(body!['id'] as String)) {
        paid -= body['amount'] as int;
        deliveries[body['id'] as String] = Map.of(body);
        if ((body['sku'] as String).contains(':')) {
          owned.add(body['sku'] as String);
        }
      }
      if (loseSpendResponse) {
        loseSpendResponse = false;
        throw const SocketException('lost');
      }
      return wallet;
    }
    if (path.endsWith('/ack')) {
      deliveries.remove(path.split('/')[3]);
      return {'ok': true};
    }
    throw StateError('Unexpected route $path');
  }
}

class FakePurchaseGateway implements PurchaseGateway {
  final stream = StreamController<List<PurchaseDetails>>.broadcast();
  int finishes = 0, buys = 0;
  bool finishFails = false;
  @override
  Stream<List<PurchaseDetails>> get updates => stream.stream;
  @override
  Future<bool> available() async => true;
  @override
  Future<ProductDetailsResponse> products(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: [
          ProductDetails(
            id: 'coins_1500',
            title: 'Coins',
            description: '1500 coins',
            price: '€0.99',
            rawPrice: .99,
            currencyCode: 'EUR',
          ),
        ],
        notFoundIDs: ['coins_4000'],
      );
  @override
  Future<bool> buy(ProductDetails product, String account) async {
    buys++;
    return true;
  }

  @override
  Future<void> finish(PurchaseDetails purchase) async {
    if (finishFails) throw StateError('finish failed');
    finishes++;
  }

  @override
  Future<void> restore(String account) async {}
  @override
  Future<List<PurchaseDetails>> pending() async => [];
}

PurchaseDetails event(
  PurchaseStatus status, {
  String id = '123',
  String product = 'coins_1500',
}) => PurchaseDetails(
  productID: product,
  purchaseID: id,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: 'test-token',
    source: 'google_play',
  ),
  transactionDate: '12345',
  status: status,
)..pendingCompletePurchase = true;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages = jsonDecode(config.readAsStringSync())['packages'] as List;
    final flutter = packages.firstWhere((p) => p['name'] == 'flutter');
    final sdk = Directory.fromUri(
      config.uri.resolve(flutter['rootUri'] as String),
    ).parent.parent;
    for (final font in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(
            File(
              '${sdk.path}/bin/cache/artifacts/material_fonts/${font.value}',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });
  final levels = Puzzle.decode(File('assets/levels.json').readAsStringSync());
  late GameController game;
  late FakeWalletApi api;
  late FakePurchaseGateway gateway;
  late CoinPurchases purchases;
  Map<String, dynamic>? saved;
  setUp(() {
    game = GameController(levels);
    game.persistWallet = () async {
      saved = jsonDecode(jsonEncode(game.snapshot())) as Map<String, dynamic>;
      return true;
    };
    api = FakeWalletApi();
    gateway = FakePurchaseGateway();
    purchases = CoinPurchases(
      game: game,
      api: api,
      gateway: gateway,
      platform: TargetPlatform.android,
      enabled: true,
    );
    saved = null;
  });
  tearDown(() async {
    coinPurchases = null;
    purchases.dispose();
    await gateway.stream.close();
    game.dispose();
  });

  test('checkout disabled by default', () {
    expect(purchasesEnabled, isFalse);
  });
  test(
    'pending, cancelled, failed and unknown purchases never credit or finish',
    () async {
      await purchases.start();
      for (final status in [
        PurchaseStatus.pending,
        PurchaseStatus.canceled,
        PurchaseStatus.error,
      ]) {
        await purchases.handle(event(status));
      }
      await purchases.handle(event(PurchaseStatus.purchased, product: 'fake'));
      expect(api.verifyCalls, 0);
      expect(gateway.finishes, 0);
      expect(api.paid, 1500);
    },
  );
  test(
    'store verified credit is not duplicated by repeated callback',
    () async {
      await purchases.start();
      await purchases.handle(event(PurchaseStatus.purchased));
      await purchases.handle(event(PurchaseStatus.purchased));
      expect(api.paid, 3000);
      expect(game.coins, 3000);
      expect(game.rewards.coins, 0);
    },
  );
  test(
    'lost verification reply retries safely and blocks another checkout',
    () async {
      await purchases.start();
      api.loseVerifyResponse = true;
      await purchases.handle(event(PurchaseStatus.purchased));
      expect(api.paid, 3000);
      expect(gateway.finishes, 0);
      await purchases.buy('coins_1500');
      expect(gateway.buys, 0);
      await purchases.retry();
      expect(api.paid, 3000);
      expect(game.coins, 3000);
      expect(gateway.finishes, 1);
    },
  );
  test('store finish failure retries without a second grant', () async {
    await purchases.start();
    gateway.finishFails = true;
    await purchases.handle(event(PurchaseStatus.purchased));
    gateway.finishFails = false;
    await purchases.retry();
    expect(api.paid, 3000);
    expect(gateway.finishes, 1);
  });
  test('free earned coins remain usable without backend', () async {
    game.rewards.coins = 100;
    expect(await game.spendCoins('hint'), true);
    expect(game.hints, 4);
    expect(game.coins, 20);
    expect(api.spendCalls, 0);
  });
  test(
    'mixed spend reserves earned coins and debits only missing paid coins',
    () async {
      await purchases.start();
      game.rewards.coins = 30;
      expect(await game.spendCoins('hint'), true);
      expect(game.hints, 4);
      expect(api.paid, 1450);
      expect(game.rewards.coins, 0);
      expect(api.deliveries, isEmpty);
      expect(saved!['walletDeliveries'], hasLength(1));
      expect(saved!['pendingWalletSpend'], isNull);
    },
  );
  test(
    'lost spend reply is recovered after app restart without double debit',
    () async {
      await purchases.start();
      game.rewards.coins = 30;
      api.loseSpendResponse = true;
      expect(await game.spendCoins('hint'), false);
      expect(api.paid, 1450);
      expect(game.hints, 3);
      expect(game.pendingWalletSpend, isNotNull);
      final fresh = GameController(levels)..restore(saved!);
      fresh.persistWallet = () async => true;
      final resumed = CoinPurchases(
        game: fresh,
        api: api,
        gateway: gateway,
        platform: TargetPlatform.android,
        enabled: true,
      );
      await resumed.start();
      expect(api.paid, 1450);
      expect(fresh.hints, 4);
      expect(fresh.rewards.coins, 0);
      expect(fresh.pendingWalletSpend, isNull);
      resumed.dispose();
      fresh.dispose();
    },
  );
  test('storage failure never initiates wallet debit', () async {
    await purchases.start();
    game.rewards.coins = 30;
    game.persistWallet = () async => false;
    expect(await game.spendCoins('hint'), false);
    expect(api.spendCalls, 0);
    expect(game.rewards.coins, 30);
    expect(game.pendingWalletSpend, isNull);
  });
  test('two simultaneous taps cannot debit twice', () async {
    await purchases.start();
    final results = await Future.wait([
      game.spendCoins('hint'),
      game.spendCoins('hint'),
    ]);
    expect(results.where((x) => x), hasLength(1));
    expect(api.paid, 1420);
    expect(game.hints, 4);
  });
  test(
    'undelivered revive is saved as a credit instead of affecting a new attempt',
    () async {
      await purchases.start();
      game.lives = 0;
      api.loseSpendResponse = true;
      expect(await game.spendCoins('revive'), false);
      game.reset();
      await purchases.refresh();
      expect(game.reviveCredits, 1);
      expect(game.lives, game.maxLives);
      game.lives = 0;
      expect(await game.spendCoins('revive'), true);
      expect(game.reviveCredits, 0);
      expect(api.paid, 1300);
    },
  );
  test(
    'offline backend leaves request reserved; recovery delivers once',
    () async {
      await purchases.start();
      api.offline = true;
      game.rewards.coins = 20;
      expect(await game.spendCoins('hint'), false);
      expect(game.pendingWalletSpend, isNotNull);
      expect(await game.spendCoins('hint'), false);
      api.offline = false;
      await purchases.refresh();
      expect(game.hints, 4);
      expect(api.paid, 1440);
    },
  );
  test('late revive response never revives a different lost attempt', () async {
    await purchases.start();
    game.lives = 0;
    final savedLocally = game.persistWallet!;
    var firstSave = true;
    game.persistWallet = () async {
      final result = await savedLocally();
      if (firstSave) {
        firstSave = false;
        game.reset();
        game.lives = 0;
      }
      return result;
    };
    expect(await game.spendCoins('revive'), true);
    expect(game.status, GameStatus.lost);
    expect(game.reviveCredits, 1);
    expect(api.paid, 1300);
  });
  test(
    'recovered permanent ownership does not bypass chapter progression',
    () async {
      api.owned.add('companion:2');
      await purchases.start();
      expect(game.inventory.companions.contains(2), true);
      expect(game.isUnlocked(30), false);
    },
  );
  testWidgets('shop uses localized price and disables missing product', (
    tester,
  ) async {
    await purchases.start();
    coinPurchases = purchases;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: CoinOptions(game: game)),
        ),
      ),
    );
    expect(find.text('1500 coins · €0.99'), findsOneWidget);
    expect(find.text('4000 coins · Unavailable'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('coin-pack-4000')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('native coin shop fits a small phone and renders a preview', (
    tester,
  ) async {
    await purchases.start();
    coinPurchases = purchases;
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          home: Scaffold(body: CoinShop(game: game, initialTab: 4)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final picture = await boundary.toImage(pixelRatio: 2);
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      Directory('work/flutter-previews').createSync(recursive: true);
      File(
        'work/flutter-previews/native-coin-shop.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      picture.dispose();
    });
    await tester.pumpWidget(const SizedBox());
  });
}
