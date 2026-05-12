import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Statut du match ──────────────────────────────────────────────────────────

/// Représente l'état global du match : en cours, ou victoire d'une équipe.
enum VolleyballMatchStatus { inProgress, teamAWins, teamBWins }

// ─── État ─────────────────────────────────────────────────────────────────────

/// Contient toutes les données du match à un instant donné.
/// Classe immutable : on ne modifie jamais directement ses champs,
/// on crée toujours une nouvelle instance via copyWith().
class VolleyballState {
  final int currentSetScoreA;
  final int currentSetScoreB;
  final int setsWonA;
  final int setsWonB;
  final int currentSetNumber;

  /// Historique des sets terminés, ex: [{a: 25, b: 18}, {a: 23, b: 25}]
  final List<Map<String, int>> setsHistory;

  final VolleyballMatchStatus matchStatus;

  const VolleyballState({
    this.currentSetScoreA = 0,
    this.currentSetScoreB = 0,
    this.setsWonA = 0,
    this.setsWonB = 0,
    this.currentSetNumber = 1,
    this.setsHistory = const [],
    this.matchStatus = VolleyballMatchStatus.inProgress,
  });

  /// Crée une copie de l'état en ne changeant que les champs fournis.
  VolleyballState copyWith({
    int? currentSetScoreA,
    int? currentSetScoreB,
    int? setsWonA,
    int? setsWonB,
    int? currentSetNumber,
    List<Map<String, int>>? setsHistory,
    VolleyballMatchStatus? matchStatus,
  }) =>
      VolleyballState(
        currentSetScoreA: currentSetScoreA ?? this.currentSetScoreA,
        currentSetScoreB: currentSetScoreB ?? this.currentSetScoreB,
        setsWonA: setsWonA ?? this.setsWonA,
        setsWonB: setsWonB ?? this.setsWonB,
        currentSetNumber: currentSetNumber ?? this.currentSetNumber,
        setsHistory: setsHistory ?? this.setsHistory,
        matchStatus: matchStatus ?? this.matchStatus,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

/// Gère toute la logique du match de volleyball.
/// C'est lui qui reçoit les actions (point marqué, annulation, reset)
/// et met à jour l'état en conséquence.
class VolleyballNotifier extends StateNotifier<VolleyballState> {
  VolleyballNotifier() : super(const VolleyballState());

  // ── Points ──────────────────────────────────────────────────────────────────

  /// Ajoute 1 point à l'équipe A, puis vérifie si le set ou le match est gagné.
  void addPointA() {
    if (state.matchStatus != VolleyballMatchStatus.inProgress) return;
    state = state.copyWith(currentSetScoreA: state.currentSetScoreA + 1);
    _checkSetWin();
  }

  /// Ajoute 1 point à l'équipe B, puis vérifie si le set ou le match est gagné.
  void addPointB() {
    if (state.matchStatus != VolleyballMatchStatus.inProgress) return;
    state = state.copyWith(currentSetScoreB: state.currentSetScoreB + 1);
    _checkSetWin();
  }

  /// Retire 1 point à l'équipe A (minimum 0).
  /// Utile pour corriger une erreur de saisie en cours de set.
  void removePointA() {
    if (state.matchStatus != VolleyballMatchStatus.inProgress) return;
    if (state.currentSetScoreA <= 0) return;
    state = state.copyWith(currentSetScoreA: state.currentSetScoreA - 1);
  }

  /// Retire 1 point à l'équipe B (minimum 0).
  /// Utile pour corriger une erreur de saisie en cours de set.
  void removePointB() {
    if (state.matchStatus != VolleyballMatchStatus.inProgress) return;
    if (state.currentSetScoreB <= 0) return;
    state = state.copyWith(currentSetScoreB: state.currentSetScoreB - 1);
  }

  // ── Logique interne ─────────────────────────────────────────────────────────

  /// Vérifie si le set en cours est terminé après chaque point marqué.
  ///
  /// Règles :
  /// - Sets 1 à 4 : il faut atteindre 25 points avec au moins 2 points d'écart.
  /// - Set 5 (tie-break) : il faut atteindre 15 points avec au moins 2 points d'écart.
  void _checkSetWin() {
    final scoreA = state.currentSetScoreA;
    final scoreB = state.currentSetScoreB;
    final isTiebreak = state.currentSetNumber == 5;
    final target = isTiebreak ? 15 : 25;

    // L'équipe A remporte le set
    if (scoreA >= target && (scoreA - scoreB) >= 2) {
      _closeSet(winnerIsA: true);
      return;
    }

    // L'équipe B remporte le set
    if (scoreB >= target && (scoreB - scoreA) >= 2) {
      _closeSet(winnerIsA: false);
    }
  }

  /// Clôture le set en cours : enregistre le score dans l'historique,
  /// incrémente les sets gagnés du vainqueur, puis démarre le set suivant
  /// (ou termine le match si une équipe a atteint 3 sets gagnés).
  void _closeSet({required bool winnerIsA}) {
    final history = [
      ...state.setsHistory,
      {'a': state.currentSetScoreA, 'b': state.currentSetScoreB},
    ];

    final newSetsWonA = state.setsWonA + (winnerIsA ? 1 : 0);
    final newSetsWonB = state.setsWonB + (winnerIsA ? 0 : 1);

    state = state.copyWith(
      setsHistory: history,
      setsWonA: newSetsWonA,
      setsWonB: newSetsWonB,
      // Remet les scores du set à zéro pour le prochain set
      currentSetScoreA: 0,
      currentSetScoreB: 0,
      currentSetNumber: state.currentSetNumber + 1,
    );

    // Vérifie si le match est terminé après avoir mis à jour les sets gagnés
    _checkMatchWin(newSetsWonA, newSetsWonB);
  }

  /// Vérifie si une équipe a remporté 3 sets et met fin au match si c'est le cas.
  /// Un match de volleyball se joue en 3 sets gagnants (au meilleur des 5).
  void _checkMatchWin(int setsWonA, int setsWonB) {
    if (setsWonA >= 3) {
      state = state.copyWith(matchStatus: VolleyballMatchStatus.teamAWins);
    } else if (setsWonB >= 3) {
      state = state.copyWith(matchStatus: VolleyballMatchStatus.teamBWins);
    }
  }

  // ── Reset ───────────────────────────────────────────────────────────────────

  /// Remet entièrement le match à zéro : scores, sets, historique et statut.
  void resetMatch() {
    state = const VolleyballState();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Point d'accès global à l'état du match de volleyball.
/// Utilise StateNotifierProvider pour que l'interface se reconstruise
/// automatiquement à chaque changement d'état.
final volleyballProvider =
    StateNotifierProvider<VolleyballNotifier, VolleyballState>(
  (ref) => VolleyballNotifier(),
);
