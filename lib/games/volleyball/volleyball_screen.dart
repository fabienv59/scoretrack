import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme.dart';
import 'volleyball_logic.dart';

// ─── Écran principal ──────────────────────────────────────────────────────────

/// Écran de jeu volleyball.
/// Reçoit les noms des deux équipes depuis l'écran de configuration.
class VolleyballScreen extends ConsumerWidget {
  final String teamAName;
  final String teamBName;

  const VolleyballScreen({
    super.key,
    required this.teamAName,
    required this.teamBName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(volleyballProvider);
    final notifier = ref.read(volleyballProvider.notifier);

    // Affiche le dialogue de fin de match dès que le statut change
    if (state.matchStatus != VolleyballMatchStatus.inProgress) {
      // On diffère l'affichage après le build pour éviter les erreurs Flutter
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEndDialog(context, ref, state);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('🏐  Volleyball'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => _confirmQuit(context, notifier),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── 1. Header : numéro de set + score des sets ──────────────────
            _SetHeader(state: state, teamAName: teamAName, teamBName: teamBName),

            // ── 2. Scoreboard principal : deux colonnes avec scores et boutons
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Colonne équipe A
                    Expanded(
                      child: _TeamPanel(
                        teamName: teamAName,
                        score: state.currentSetScoreA,
                        isLeft: true,
                        matchOver: state.matchStatus != VolleyballMatchStatus.inProgress,
                        onAdd: notifier.addPointA,
                        onRemove: notifier.removePointA,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Colonne équipe B
                    Expanded(
                      child: _TeamPanel(
                        teamName: teamBName,
                        score: state.currentSetScoreB,
                        isLeft: false,
                        matchOver: state.matchStatus != VolleyballMatchStatus.inProgress,
                        onAdd: notifier.addPointB,
                        onRemove: notifier.removePointB,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 3. Historique des sets précédents ───────────────────────────
            _SetsHistory(history: state.setsHistory),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Dialogue de confirmation avant de quitter ─────────────────────────────

  /// Demande confirmation avant de quitter, pour éviter une sortie accidentelle.
  void _confirmQuit(BuildContext context, VolleyballNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter la partie ?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'La partie en cours sera perdue.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continuer',
                style: TextStyle(color: AppColors.accent)),
          ),
          TextButton(
            onPressed: () {
              notifier.resetMatch();
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Quitter',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  // ── Dialogue de fin de match ──────────────────────────────────────────────

  /// Affiche le vainqueur et propose de rejouer ou de quitter.
  void _showEndDialog(BuildContext context, WidgetRef ref, VolleyballState state) {
    // Évite d'afficher le dialogue plusieurs fois si déjà ouvert
    if (ModalRoute.of(context)?.isCurrent == false) return;

    final notifier = ref.read(volleyballProvider.notifier);
    final winnerName =
        state.matchStatus == VolleyballMatchStatus.teamAWins ? teamAName : teamBName;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏐', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              winnerName,
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'remporte le match !',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            // Score final des sets
            Text(
              '${state.setsWonA} — ${state.setsWonB}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          // Bouton Nouvelle partie
          ElevatedButton(
            onPressed: () {
              notifier.resetMatch();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(140, 48),
            ),
            child: const Text('Nouvelle partie'),
          ),
          const SizedBox(height: 8),
          // Bouton Quitter
          TextButton(
            onPressed: () {
              notifier.resetMatch();
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Quitter',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ─── Widget : Header (numéro de set + pastilles) ──────────────────────────────

/// Barre du haut affichant le set en cours et les sets remportés par chaque équipe.
class _SetHeader extends StatelessWidget {
  final VolleyballState state;
  final String teamAName;
  final String teamBName;

  const _SetHeader({
    required this.state,
    required this.teamAName,
    required this.teamBName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Pastilles sets équipe A (gauche)
          _SetDots(setsWon: state.setsWonA, alignLeft: true),

          // Numéro de set centré
          Column(
            children: [
              Text(
                'Set ${state.currentSetNumber}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'sur 5',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),

          // Pastilles sets équipe B (droite)
          _SetDots(setsWon: state.setsWonB, alignLeft: false),
        ],
      ),
    );
  }
}

// ─── Widget : Pastilles de sets gagnés ───────────────────────────────────────

/// Affiche jusqu'à 3 pastilles colorées représentant les sets remportés.
/// Les pastilles remplies = sets gagnés, les vides = sets restants à gagner.
class _SetDots extends StatelessWidget {
  final int setsWon;
  final bool alignLeft;

  const _SetDots({required this.setsWon, required this.alignLeft});

  @override
  Widget build(BuildContext context) {
    // On affiche toujours 3 cercles (3 sets gagnants max)
    final dots = List.generate(3, (i) {
      final filled = i < setsWon;
      return Container(
        width: 14,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? AppColors.success : Colors.transparent,
          border: Border.all(
            color: filled ? AppColors.success : AppColors.textSecondary,
            width: 2,
          ),
        ),
      );
    });

    return Row(
      children: alignLeft ? dots : dots.reversed.toList(),
    );
  }
}

// ─── Widget : Panneau d'une équipe ────────────────────────────────────────────

/// Colonne verticale affichant le nom, le score et les boutons +/- pour une équipe.
class _TeamPanel extends StatelessWidget {
  final String teamName;
  final int score;
  final bool isLeft;
  final bool matchOver;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _TeamPanel({
    required this.teamName,
    required this.score,
    required this.isLeft,
    required this.matchOver,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // ── Bouton [-] en haut, discret ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 10, right: 10, left: 10),
            child: Align(
              alignment: isLeft ? Alignment.centerRight : Alignment.centerLeft,
              child: GestureDetector(
                onTap: matchOver ? null : onRemove,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.textSecondary.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.remove,
                      size: 16, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),

          // ── Nom de l'équipe ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              teamName,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 4),

          // ── Score du set en très grand ──────────────────────────────────
          Expanded(
            child: Center(
              child: Text(
                '$score',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 80,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),

          // ── Bouton [+] en bas, bien visible ────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: matchOver ? null : onAdd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: matchOver
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widget : Historique des sets ────────────────────────────────────────────

/// Ligne compacte affichant les scores de tous les sets déjà terminés.
/// Ex : "25-18  |  23-25  |  25-20"
class _SetsHistory extends StatelessWidget {
  final List<Map<String, int>> history;

  const _SetsHistory({required this.history});

  @override
  Widget build(BuildContext context) {
    // On n'affiche rien si aucun set n'est terminé
    if (history.isEmpty) {
      return const SizedBox(height: 24);
    }

    // Construit la liste des scores "25-18" séparés par "|"
    final parts = <Widget>[];
    for (int i = 0; i < history.length; i++) {
      final set = history[i];
      final scoreA = set['a'] ?? 0;
      final scoreB = set['b'] ?? 0;

      // Détermine la couleur : vert si A a gagné ce set, gris sinon
      final aWon = scoreA > scoreB;

      parts.add(
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$scoreA',
                style: TextStyle(
                  color: aWon ? AppColors.success : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(
                text: '-',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              TextSpan(
                text: '$scoreB',
                style: TextStyle(
                  color: !aWon ? AppColors.success : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );

      // Séparateur entre les sets (sauf après le dernier)
      if (i < history.length - 1) {
        parts.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('|',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: parts,
      ),
    );
  }
}
