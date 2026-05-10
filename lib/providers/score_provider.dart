import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScoreState {
  final List<int> scores; // index 0..N-1
  final bool isGameOver;
  final int? winnerId; // 0-indexed, null = match nul
  final bool canUndo;

  const ScoreState({
    required this.scores,
    this.isGameOver = false,
    this.winnerId,
    this.canUndo = false,
  });

  // Accesseurs de compatibilité
  int get score1 => scores.isNotEmpty ? scores[0] : 0;
  int get score2 => scores.length > 1 ? scores[1] : 0;
  int get teamCount => scores.length;
}

class ScoreNotifier extends StateNotifier<ScoreState> {
  int _target = 0;
  final _history = <List<int>>[];

  ScoreNotifier() : super(const ScoreState(scores: [0, 0]));

  void startGame({int teamCount = 2, int targetScore = 0}) {
    _target = targetScore;
    _history.clear();
    state = ScoreState(scores: List<int>.filled(teamCount, 0));
  }

  void increment(int index) {
    if (state.isGameOver || index >= state.scores.length) return;
    _push();
    final s = List<int>.from(state.scores);
    s[index]++;
    _updateScores(s);
  }

  void addPoints(int index, int amount) {
    if (state.isGameOver || index >= state.scores.length) return;
    _push();
    final s = List<int>.from(state.scores);
    s[index] = (s[index] + amount).clamp(0, 9999);
    _updateScores(s);
  }

  void decrement(int index) {
    if (state.isGameOver || index >= state.scores.length) return;
    _push();
    final s = List<int>.from(state.scores)
      ..[index] = (state.scores[index] - 1).clamp(0, 9999);
    state = ScoreState(scores: s, canUndo: _history.isNotEmpty);
  }

  void setScore(int index, int value) {
    if (state.isGameOver || index >= state.scores.length) return;
    _push();
    final s = List<int>.from(state.scores)..[index] = value.clamp(0, 9999);
    _updateScores(s);
  }

  void undo() {
    if (_history.isEmpty) return;
    final prev = _history.removeLast();
    state = ScoreState(scores: prev, canUndo: _history.isNotEmpty);
  }

  void endGame() {
    final maxScore = state.scores.reduce(max);
    final isTied =
        state.scores.where((s) => s == maxScore).length > 1;
    state = ScoreState(
      scores: List.from(state.scores),
      isGameOver: true,
      winnerId: isTied ? null : state.scores.indexOf(maxScore),
    );
  }

  void _push() => _history.add(List<int>.from(state.scores));

  void _updateScores(List<int> s) {
    if (_target > 0) {
      for (int i = 0; i < s.length; i++) {
        if (s[i] >= _target) {
          state = ScoreState(scores: s, isGameOver: true, winnerId: i);
          return;
        }
      }
    }
    state = ScoreState(scores: s, canUndo: _history.isNotEmpty);
  }
}

final scoreProvider =
    StateNotifierProvider<ScoreNotifier, ScoreState>((ref) => ScoreNotifier());
