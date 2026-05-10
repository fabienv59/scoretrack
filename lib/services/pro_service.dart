import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kProProductId = 'scoretrack_pro_yearly';
const String _kIsProKey = 'is_pro';

class ProService {
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _storeAvailable = false;

  bool get isStoreAvailable => _storeAvailable;

  // Callbacks vers ProNotifier
  void Function(bool isPro)? onProStatusChanged;
  void Function(bool isLoading)? onLoadingChanged;
  void Function(String error)? onErrorOccurred;

  Future<bool> loadLocalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsProKey) ?? false;
  }

  Future<void> saveLocalStatus(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsProKey, value);
  }

  Future<void> initialize() async {
    // IAP uniquement sur Android et iOS
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    _storeAvailable = await InAppPurchase.instance.isAvailable();
    if (!_storeAvailable) return;

    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) => onErrorOccurred?.call(error.toString()),
    );

    // Restauration silencieuse au démarrage
    await InAppPurchase.instance.restorePurchases();
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != _kProProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          onLoadingChanged?.call(true);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await saveLocalStatus(true);
          onProStatusChanged?.call(true);
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.error:
          onLoadingChanged?.call(false);
          onErrorOccurred?.call(
            purchase.error?.message ?? "Erreur lors de l'achat",
          );
          break;
        case PurchaseStatus.canceled:
          onLoadingChanged?.call(false);
          break;
      }
    }
  }

  Future<void> purchasePro() async {
    if (!_storeAvailable) {
      onErrorOccurred?.call('Store Google Play non disponible');
      onLoadingChanged?.call(false);
      return;
    }

    final response = await InAppPurchase.instance.queryProductDetails(
      {_kProProductId},
    );

    if (response.productDetails.isEmpty) {
      onErrorOccurred?.call('Produit introuvable dans le Store');
      onLoadingChanged?.call(false);
      return;
    }

    final purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
    );
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: purchaseParam,
    );
  }

  Future<void> restorePurchases() async {
    if (!_storeAvailable) {
      onErrorOccurred?.call('Store Google Play non disponible');
      onLoadingChanged?.call(false);
      return;
    }
    await InAppPurchase.instance.restorePurchases();
    // Si aucun achat trouvé, le stream ne se déclenche pas → reset après timeout
    Future.delayed(const Duration(seconds: 5), () {
      onLoadingChanged?.call(false);
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}
