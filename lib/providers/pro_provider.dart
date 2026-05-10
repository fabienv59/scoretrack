import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pro_service.dart';

class ProState {
  final bool isPro;
  final bool isLoading;
  final String? errorMessage;

  const ProState({
    required this.isPro,
    this.isLoading = false,
    this.errorMessage,
  });

  ProState copyWith({
    bool? isPro,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProState(
      isPro: isPro ?? this.isPro,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ProNotifier extends StateNotifier<ProState> {
  final ProService _service;

  ProNotifier(this._service) : super(const ProState(isPro: false)) {
    _init();
  }

  Future<void> _init() async {
    final cachedIsPro = await _service.loadLocalStatus();
    if (!mounted) return;
    state = state.copyWith(isPro: cachedIsPro);

    _service.onProStatusChanged = (isPro) {
      if (!mounted) return;
      state = state.copyWith(isPro: isPro, isLoading: false, clearError: true);
    };
    _service.onLoadingChanged = (isLoading) {
      if (!mounted) return;
      state = state.copyWith(isLoading: isLoading);
    };
    _service.onErrorOccurred = (error) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: error);
    };

    await _service.initialize();
  }

  Future<void> purchasePro() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _service.purchasePro();
  }

  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _service.restorePurchases();
  }

  Future<void> revoke() async {
    await _service.saveLocalStatus(false);
    state = state.copyWith(isPro: false);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

final _proServiceProvider = Provider((ref) => ProService());

final proProvider = StateNotifierProvider<ProNotifier, ProState>(
  (ref) => ProNotifier(ref.watch(_proServiceProvider)),
);
