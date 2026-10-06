import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart'
    show SKRequestMaker;
import 'game_controller.dart';
import 'paid_wallet.dart';
import 'wallet_api.dart';

const coinPacks = [
  (id: 'coins_1500', amount: 1500, price: '₹49'),
  (id: 'coins_4000', amount: 4000, price: '₹99'),
];

abstract interface class PurchaseGateway {
  Stream<List<PurchaseDetails>> get updates;
  Future<bool> available();
  Future<ProductDetailsResponse> products(Set<String> ids);
  Future<bool> buy(ProductDetails product, String account);
  Future<void> finish(PurchaseDetails purchase);
  Future<void> restore(String account);
  Future<List<PurchaseDetails>> pending();
}

class NativePurchaseGateway implements PurchaseGateway {
  NativePurchaseGateway(this.platform);
  final TargetPlatform platform;
  InAppPurchase get store => InAppPurchase.instance;
  @override
  Stream<List<PurchaseDetails>> get updates => store.purchaseStream;
  @override
  Future<bool> available() async {
    if (platform == TargetPlatform.iOS &&
        !await SKRequestMaker.supportsStoreKit2()) {
      return false;
    }
    return store.isAvailable();
  }

  @override
  Future<ProductDetailsResponse> products(Set<String> ids) =>
      store.queryProductDetails(ids);
  @override
  Future<bool> buy(ProductDetails product, String account) =>
      store.buyConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          applicationUserName: account,
        ),
        autoConsume: platform != TargetPlatform.android,
      );
  @override
  Future<void> finish(PurchaseDetails purchase) async {
    if (platform == TargetPlatform.android) {
      final result = await store
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .consumePurchase(purchase);
      // Already consumed may occur when the response was lost on a previous try.
      if (result.responseCode != BillingResponse.ok &&
          result.responseCode != BillingResponse.itemNotOwned) {
        throw StateError('Store could not finish the purchase');
      }
    } else if (purchase.pendingCompletePurchase) {
      await store.completePurchase(purchase);
    }
  }

  @override
  Future<void> restore(String account) =>
      store.restorePurchases(applicationUserName: account);
  @override
  Future<List<PurchaseDetails>> pending() async {
    if (platform == TargetPlatform.iOS) {
      if (!await SKRequestMaker.supportsStoreKit2()) return [];
      return (await SK2Transaction.unfinishedTransactions())
          .map(
            (transaction) => SK2PurchaseDetails(
              productID: transaction.productId,
              purchaseID: transaction.id,
              verificationData: PurchaseVerificationData(
                localVerificationData: '',
                serverVerificationData: transaction.receiptData ?? '',
                source: 'app_store',
              ),
              transactionDate: transaction.purchaseDate,
              status: PurchaseStatus.purchased,
              appAccountToken: transaction.appAccountToken,
            ),
          )
          .toList();
    }
    if (platform != TargetPlatform.android) return [];
    final result = await store
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
        .queryPastPurchases();
    if (result.error != null) {
      throw StateError('Pending purchases could not be checked');
    }
    return result.pastPurchases;
  }
}

class CoinPurchases extends ChangeNotifier implements PaidWallet {
  CoinPurchases({
    required this.game,
    required this.api,
    required this.gateway,
    required this.platform,
    this.enabled = purchasesEnabled,
  });
  final GameController game;
  final WalletApi api;
  final PurchaseGateway gateway;
  final TargetPlatform platform;
  final bool enabled;
  final Map<String, ProductDetails> products = {};
  final Map<String, PurchaseDetails> _retry = {};
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> _events = Future.value();
  Future<void>? _starting;
  bool loading = false, purchasing = false, ready = false;
  String message =
      'Coin purchases are not configured yet. You can still earn coins by playing.';
  @override
  int balance = 0;
  int debt = 0;
  int _revision = -1;
  String get platformName => platform == TargetPlatform.iOS ? 'ios' : 'android';
  bool get supported =>
      !kIsWeb &&
      [TargetPlatform.android, TargetPlatform.iOS].contains(platform);
  void changed() {
    notifyListeners();
    game.walletChanged();
  }

  Future<void> start() =>
      _starting ??= _start().whenComplete(() => _starting = null);
  Future<void> _start() async {
    if (!enabled ||
        !api.configured ||
        !supported ||
        game.adminTesting ||
        game.persistWallet == null) {
      return;
    }
    loading = true;
    changed();
    try {
      if (!await gateway.available()) {
        ready = false;
        message =
            'Store purchases are unavailable on this device (iPhone purchases require iOS 15 or later).';
        return;
      }
      // Register before querying products; unfinished payments arrive on this stream.
      _subscription ??= gateway.updates.listen(
        (batch) {
          for (final purchase in batch) {
            _events = _events.then((_) => handle(purchase)).catchError((
              Object _,
            ) {
              message = 'Purchase waiting for verification. Tap Retry / sync.';
              purchasing = false;
              changed();
            });
          }
        },
        onError: (Object _) {
          purchasing = false;
          message = 'The store connection was interrupted. Tap Retry / sync.';
          changed();
        },
      );
      await api.connect();
      game.paidWallet = this;
      await refresh();
      for (final purchase in await gateway.pending()) {
        _events = _events.then((_) => handle(purchase));
      }
      final config = await api.request('GET', '/v1/config');
      if (config[platformName] != true || !await gateway.available()) {
        ready = false;
        message =
            'Coin checkout is unavailable. Your existing purchased coins are safe.';
        return;
      }
      final result = await gateway.products(coinPacks.map((p) => p.id).toSet());
      products
        ..clear()
        ..addEntries(result.productDetails.map((p) => MapEntry(p.id, p)));
      ready = result.error == null && products.isNotEmpty;
      message = ready
          ? 'Payment is handled securely by ${platform == TargetPlatform.iOS ? 'Apple' : 'Google Play'}.'
          : 'The store has not made these coin packs available yet.';
    } catch (_) {
      ready = false;
      message =
          'The coin shop could not connect. Tap Retry / sync; gameplay still works offline.';
    } finally {
      loading = false;
      changed();
    }
  }

  Future<void> buy(String productId) async {
    if (!ready ||
        loading ||
        purchasing ||
        _retry.isNotEmpty ||
        !products.containsKey(productId)) {
      return;
    }
    purchasing = true;
    message = 'Waiting for the store…';
    changed();
    try {
      if (!await gateway.buy(products[productId]!, api.accountId!)) {
        purchasing = false;
        message = 'Purchase did not start. Please try again.';
      }
    } catch (_) {
      purchasing = false;
      message = 'The store could not open. Please try again.';
    }
    changed();
  }

  Future<void> handle(PurchaseDetails purchase) async {
    if (!coinPacks.any((p) => p.id == purchase.productID)) return;
    if (purchase.status == PurchaseStatus.pending) {
      message =
          'Payment is pending store approval. Coins arrive after confirmation.';
      purchasing = true;
      changed();
      return;
    }
    if (purchase.status == PurchaseStatus.canceled ||
        purchase.status == PurchaseStatus.error) {
      purchasing = false;
      message = purchase.status == PurchaseStatus.canceled
          ? 'Purchase cancelled. No coins added.'
          : 'The store reported a payment error. No coins added.';
      changed();
      return;
    }
    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      return;
    }
    final key =
        '${purchase.productID}:${purchase.purchaseID ?? purchase.verificationData.serverVerificationData}';
    _retry[key] = purchase;
    try {
      if (api.accountId == null) await api.connect();
      game.paidWallet = this;
      final wallet = await api.request('POST', '/v1/purchases/verify', {
        'platform': platformName,
        'productId': purchase.productID,
        'transactionId': purchase.purchaseID,
        if (platform == TargetPlatform.android)
          'token': purchase.verificationData.serverVerificationData,
      });
      await accept(wallet);
      // Server has atomically credited the wallet before consuming/finishing.
      await gateway.finish(purchase);
      _retry.remove(key);
      message = 'Purchase confirmed. Your wallet is up to date.';
    } catch (_) {
      message =
          'Your purchase needs verification. Tap Retry / sync. Do not buy it again.';
    } finally {
      purchasing = false;
      changed();
    }
  }

  Future<void> retry() async {
    if (loading) return;
    await start();
    if (api.accountId == null) return;
    try {
      await _events;
      for (final purchase in _retry.values.toList()) {
        await handle(purchase);
      }
      for (final purchase in await gateway.pending()) {
        await handle(purchase);
      }
      await refresh();
    } catch (_) {
      message = 'Sync could not finish. Please try again online.';
    }
    changed();
  }

  Future<void> accept(Map<String, dynamic> wallet) async {
    final revision = wallet['revision'] as int? ?? 0;
    if (revision < _revision) return;
    _revision = revision;
    balance = wallet['balance'] as int;
    debt = wallet['debt'] as int? ?? 0;
    await game.applyWallet(wallet);
    changed();
  }

  @override
  Future<void> refresh() async {
    await accept(await api.request('GET', '/v1/wallet'));
    await game.retryWalletSpend();
  }

  @override
  Future<Map<String, dynamic>> spend(Map<String, dynamic> request) async {
    try {
      final result = await api.request('POST', '/v1/spends', {
        'id': request['id'],
        'sku': request['sku'],
        'amount': request['amount'],
      });
      if ((result['revision'] as int? ?? 0) >= _revision) {
        _revision = result['revision'] as int? ?? 0;
        balance = result['balance'] as int;
      }
      return result;
    } on WalletApiException catch (error) {
      // These responses guarantee the debit did not happen. Network failures do not.
      if ([
        'insufficient_coins',
        'already_owned',
        'invalid_spend',
      ].contains(error.code)) {
        game.rewards.coins += (game.pendingWalletSpend?['earned'] as int? ?? 0);
        game.pendingWalletSpend = null;
        await game.persistWallet?.call();
      }
      rethrow;
    }
  }

  @override
  Future<void> acknowledge(String id) async {
    await api.request('POST', '/v1/spends/$id/ack');
  }

  Future<void> recover(String token) async {
    if (purchasing ||
        loading ||
        _retry.isNotEmpty ||
        game.pendingWalletSpend != null) {
      throw StateError('Finish the pending purchase first');
    }
    await api.recover(token.trim());
    _revision = -1;
    game.paidWallet = this;
    await refresh();
    changed();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

CoinPurchases? coinPurchases;
