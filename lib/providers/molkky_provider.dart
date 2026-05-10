import 'package:flutter_riverpod/flutter_riverpod.dart';

const int kMolkkyTarget = 50;
const int kMolkkyOverPenalty = 25;
const int kMolkkyMaxMisses = 3;

// ─── Modèles ───────────────────────────────────────────────────────────────────

class MolkkyTeam {
  final String name;
  final int score;
  final int consecutiveMisses;
  final bool isEliminated;

  const MolkkyTeam({
    required this.name,
    this.score = 0,
    this.consecutiveMisses = 0,
    this.isEliminated = false,
  });

  MolkkyTeam copyWith({
    String? name,
    int? score,
    int? consecutiveMisses,
    bool? isEliminated,
  }) =>
      MolkkyTeam(
        name: name ?? this.name,
        score: score ?? this.score,
        consecutiveMisses: consecutiveMisses ?? this.consecutiveMisses,
        isEliminated: isEliminated ?? this.isEliminated,
      );
}

class MolkkyState {
  final List<MolkkyTeam> teams;
  final int currentTeamIndex;
  final bool isGameOver;
  final int? winnerId;
  final bool canUndo;

  const MolkkyState({
    required this.teams,
    this.currentTeamIndex = 0,
    this.isGameOver = false,
    this.winnerId,
    this.canUndo = false,
  });

  MolkkyState copyWith({
    List<MolkkyTeam>? teams,
    int? currentTeamIndex,
    bool? isGameOver,
    int? winnerId,
    bool? canUndo,
  }) =>
      MolkkyState(
        teams: teams ?? this.teams,
        currentTeamIndex: currentTeamIndex ?? this.currentTeamIndex,
        isGameOver: isGameOver ?? this.isGameOver,
        winnerId: winnerId ?? this.winnerId,
        canUndo: canUndo ?? this.canUndo,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MolkkyNotifier extends StateNotifier<MolkkyState> {
  final _history = <MolkkyState>[];

  MolkkyNotifier()
      : super(MolkkyState(
          teams: const [
            MolkkyTeam(name: 'Équipe 1'),
            MolkkyTeam(name: 'Équipe 2'),
          ],
        ));

  void init(List<String> teamNames) {
    _history.clear();
    state = MolkkyState(
      teams: teamNames.map((n) => MolkkyTeam(name: n)).toList(),
    );
  }

  /// Lancer raté : +1 miss ; à 3 misses l'équipe est éliminée.
  void recordMiss() {
    if (state.isGameOver) return;
    _push();
    final curr = state.currentTeamIndex;
    final teams = List<MolkkyTeam>.from(state.teams);
    final newMisses = teams[curr].consecutiveMisses + 1;

    if (newMisses >= kMolkkyMaxMisses) {
      teams[curr] = teams[curr]
          .copyWith(consecutiveMisses: newMisses, isEliminated: true);
      state = state.copyWith(
        teams: teams,
        isGameOver: true,
        winnerId: 1 - curr,
        canUndo: true,
      );
    } else {
      teams[curr] = teams[curr].copyWith(consecutiveMisses: newMisses);
      state = state.copyWith(
        teams: teams,
        currentTeamIndex: 1 - curr,
        canUndo: true,
      );
    }
  }

  /// Lancer avec points :
  ///   - 1 quille → points = numéro de la quille (1-12)
  ///   - N quilles → points = N (2-12)
  /// Atteindre 50 → victoire ; dépasser 50 → retombe à 25.
  void recordThrow(int points) {
    if (state.isGameOver || points <= 0) return;
    _push();
    final curr = state.currentTeamIndex;
    final teams = List<MolkkyTeam>.from(state.teams);
    int newScore = teams[curr].score + points;

    if (newScore == kMolkkyTarget) {
      teams[curr] =
          teams[curr].copyWith(score: kMolkkyTarget, consecutiveMisses: 0);
      state = state.copyWith(
        teams: teams,
        isGameOver: true,
        winnerId: curr,
        canUndo: true,
      );
      return;
    }

    if (newScore > kMolkkyTarget) {
      newScore = kMolkkyOverPenalty;
    }

    teams[curr] = teams[curr].copyWith(score: newScore, consecutiveMisses: 0);
    state = state.copyWith(
      teams: teams,
      currentTeamIndex: 1 - curr,
      canUndo: true,
    );
  }

  void undo() {
    if (_history.isEmpty) return;
    state = _history.removeLast().copyWith(canUndo: _history.isNotEmpty);
  }

  void _push() => _history.add(state);
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final molkkyProvider =
    StateNotifierProvider<MolkkyNotifier, MolkkyState>(
  (ref) => MolkkyNotifier(),
);
