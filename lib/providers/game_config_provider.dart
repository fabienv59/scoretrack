import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_config.dart';

class GameConfigNotifier extends StateNotifier<GameConfig?> {
  GameConfigNotifier() : super(null);

  void setConfig(GameConfig config) => state = config;
  void clear() => state = null;
}

final gameConfigProvider =
    StateNotifierProvider<GameConfigNotifier, GameConfig?>(
  (ref) => GameConfigNotifier(),
);
