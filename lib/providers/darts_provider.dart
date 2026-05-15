import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/darts_variant.dart';

// Zones RTC : 1-20 puis Bull (index 20)
const int kRtcTotalZones = 21;
const List<String> kRtcZoneLabels = [
  '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
  '11', '12', '13', '14', '15', '16', '17', '18', '19', '20',
  'Bull',
];

// ─── Modèles ───────────────────────────────────────────────────────────────────

class DartsPlayer {
  final String name;
  // countdown : score restant | countUp : score accumulé | rtc : zones validées
  final int score;
  final int roundsPlayed; // countUp uniquement

  const DartsPlayer({
    required this.name,
    this.score = 0,
    this.roundsPlayed = 0,
  });

  DartsPlayer copyWith({String? name, int? score, int? roundsPlayed}) =>
      DartsPlayer(
        name: name ?? this.name,
        score: score ?? this.score,
        roundsPlayed: roundsPlayed ?? this.roundsPlayed,
      );
}

class DartsState {
  final DartsVariant variant;
  final List<DartsPlayer> players;
  final int currentPlayerIndex;
  final bool isGameOver;
  final int? winnerId; // null = égalité
  final bool canUndo;
  final bool isBust; // true pendant une seule frame (signal UI)
  final int totalRounds; // countUp

  const DartsState({
    required this.variant,
    required this.players,
    this.currentPlayerIndex = 0,
    this.isGameOver = false,
    this.winnerId,
    this.canUndo = false,
    this.isBust = false,
    this.totalRounds = 8,
  });

  DartsPlayer get currentPlayer => players[currentPlayerIndex];

  DartsState copyWith({
    DartsVariant? variant,
    List<DartsPlayer>? players,
    int? currentPlayerIndex,
    bool? isGameOver,
    int? winnerId,
    bool? canUndo,
    bool? isBust,
    int? totalRounds,
  }) =>
      DartsState(
        variant: variant ?? this.variant,
        players: players ?? this.players,
        currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
        isGameOver: isGameOver ?? this.isGameOver,
        winnerId: winnerId ?? this.winnerId,
        canUndo: canUndo ?? this.canUndo,
        isBust: isBust ?? this.isBust,
        totalRounds: totalRounds ?? this.totalRounds,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class DartsNotifier extends StateNotifier<DartsState> {
  final _history = <DartsState>[];

  DartsNotifier()
      : super(const DartsState(
          variant: DartsVariant.darts501,
          players: [
            DartsPlayer(name: 'Joueur 1', score: 501),
            DartsPlayer(name: 'Joueur 2', score: 501),
          ],
        ));

  void init(
    List<String> playerNames,
    DartsVariant variant, {
    int totalRounds = 8,
  }) {
    _history.clear();
    final initScore = variant.isCountdown ? variant.startScore : 0;
    state = DartsState(
      variant: variant,
      totalRounds: totalRounds,
      players: playerNames
          .map((n) => DartsPlayer(name: n, score: initScore))
          .toList(),
    );
  }

  // 501/301 et countUp : total de la volée (0-180)
  void recordVolley(int points, {bool doubleFinish = false}) {
    if (state.isGameOver) return;
    _push();

    final variant = state.variant;
    final players = List<DartsPlayer>.from(state.players);
    final idx = state.currentPlayerIndex;
    final player = players[idx];
    final next = (idx + 1) % players.length;

    if (variant.isCountdown) {
      final remaining = player.score - points;

      // Bust : dépassement, reste = 1 (impossible en double), ou finish sans double
      if (remaining < 0 ||
          remaining == 1 ||
          (remaining == 0 && !doubleFinish)) {
        state = state.copyWith(
          isBust: true,
          currentPlayerIndex: next,
          canUndo: _history.isNotEmpty,
        );
        return;
      }

      players[idx] = player.copyWith(score: remaining);

      if (remaining == 0) {
        state = DartsState(
          variant: variant,
          players: players,
          currentPlayerIndex: idx,
          isGameOver: true,
          winnerId: idx,
          totalRounds: state.totalRounds,
        );
        return;
      }

      state = state.copyWith(
        players: players,
        currentPlayerIndex: next,
        isBust: false,
        canUndo: _history.isNotEmpty,
      );
    } else if (variant == DartsVariant.countUp) {
      players[idx] = player.copyWith(
        score: player.score + points,
        roundsPlayed: player.roundsPlayed + 1,
      );

      final allDone =
          players.every((p) => p.roundsPlayed >= state.totalRounds);

      if (allDone) {
        final maxScore = players.map((p) => p.score).reduce((a, b) => a > b ? a : b);
        final ties = players.where((p) => p.score == maxScore).length;
        final winnerId =
            ties == 1 ? players.indexWhere((p) => p.score == maxScore) : null;
        state = DartsState(
          variant: variant,
          players: players,
          currentPlayerIndex: idx,
          isGameOver: true,
          winnerId: winnerId,
          totalRounds: state.totalRounds,
        );
        return;
      }

      state = state.copyWith(
        players: players,
        currentPlayerIndex: next,
        canUndo: _history.isNotEmpty,
      );
    }
  }

  // RoundTheClock : nombre de zones touchées dans la volée (0-3)
  void recordRtcVolley(int zonesHit) {
    if (state.isGameOver || state.variant != DartsVariant.roundTheClock) return;
    _push();

    final players = List<DartsPlayer>.from(state.players);
    final idx = state.currentPlayerIndex;
    final player = players[idx];
    final newZones = (player.score + zonesHit).clamp(0, kRtcTotalZones);
    players[idx] = player.copyWith(score: newZones);

    if (newZones >= kRtcTotalZones) {
      state = DartsState(
        variant: state.variant,
        players: players,
        currentPlayerIndex: idx,
        isGameOver: true,
        winnerId: idx,
        totalRounds: state.totalRounds,
      );
      return;
    }

    state = state.copyWith(
      players: players,
      currentPlayerIndex: (idx + 1) % players.length,
      canUndo: _history.isNotEmpty,
    );
  }

  void clearBust() {
    if (state.isBust) state = state.copyWith(isBust: false);
  }

  void undo() {
    if (_history.isEmpty) return;
    state = _history.removeLast();
  }

  void _push() => _history.add(state);
}

final dartsProvider =
    StateNotifierProvider<DartsNotifier, DartsState>((ref) => DartsNotifier());
