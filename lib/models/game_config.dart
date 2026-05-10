import 'count_mode.dart';
import 'game_type.dart';

class GameConfig {
  final GameType gameType;
  final List<String> teamNames; // 2 à 4 équipes
  final int targetScore; // 0 = score libre
  final CountMode countMode;
  final String? customLabel; // nom libre pour les jeux personnalisés

  const GameConfig({
    required this.gameType,
    required this.teamNames,
    required this.targetScore,
    this.countMode = CountMode.cumul,
    this.customLabel,
  });

  int get teamCount => teamNames.length;
  String get team1Name => teamNames.isNotEmpty ? teamNames[0] : 'Équipe 1';
  String get team2Name => teamNames.length > 1 ? teamNames[1] : 'Équipe 2';
  String get displayLabel => customLabel ?? gameType.label;
  String get displayEmoji => gameType.emoji;

  GameConfig copyWith({
    GameType? gameType,
    List<String>? teamNames,
    int? targetScore,
    CountMode? countMode,
    String? customLabel,
  }) =>
      GameConfig(
        gameType: gameType ?? this.gameType,
        teamNames: teamNames ?? this.teamNames,
        targetScore: targetScore ?? this.targetScore,
        countMode: countMode ?? this.countMode,
        customLabel: customLabel ?? this.customLabel,
      );
}
