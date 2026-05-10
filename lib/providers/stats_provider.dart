import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_record.dart';
import '../services/database_service.dart';

final allMatchesProvider = FutureProvider.autoDispose<List<MatchRecord>>((ref) {
  return DatabaseService.instance.getAllMatches();
});
