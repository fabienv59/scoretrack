import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_record.dart';
import '../services/database_service.dart';
import 'pro_provider.dart';

class HistoryNotifier extends AsyncNotifier<List<MatchRecord>> {
  @override
  Future<List<MatchRecord>> build() {
    final isPro = ref.watch(proProvider).isPro;
    if (isPro) return DatabaseService.instance.getAllMatches();
    return DatabaseService.instance.getLastMatches(limit: 5);
  }

  Future<void> addMatch(MatchRecord record) async {
    final isPro = ref.read(proProvider).isPro;
    await DatabaseService.instance.insertMatch(record);
    if (!isPro) {
      await DatabaseService.instance.deleteMatchesExceedingLimit(5);
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      final isPro = ref.read(proProvider).isPro;
      if (isPro) return DatabaseService.instance.getAllMatches();
      return DatabaseService.instance.getLastMatches(limit: 5);
    });
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<MatchRecord>>(
  HistoryNotifier.new,
);
