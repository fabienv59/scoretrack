import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/banner_ad_widget.dart';
import '../models/game_type.dart';
import '../models/match_record.dart';
import '../providers/game_config_provider.dart';
import '../providers/history_provider.dart';
import '../providers/molkky_provider.dart';
import '../providers/pro_provider.dart';
import '../theme.dart';

// ─── Mode de saisie du lancer ─────────────────────────────────────────────────

enum _ThrowMode { onePin, multiplePins }

// ─── Écran principal ──────────────────────────────────────────────────────────

class MolkkyGameScreen extends ConsumerStatefulWidget {
  const MolkkyGameScreen({super.key});

  @override
  ConsumerState<MolkkyGameScreen> createState() => _MolkkyGameScreenState();
}

class _MolkkyGameScreenState extends ConsumerState<MolkkyGameScreen> {
  _ThrowMode? _throwMode;
  bool _resultShown = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initGame());
  }

  void _initGame() {
    if (_initialized || !mounted) return;
    final config = ref.read(gameConfigProvider);
    if (config == null) {
      context.go('/home');
      return;
    }
    ref.read(molkkyProvider.notifier).init(config.teamNames);
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(molkkyProvider);
    final isPro = ref.watch(proProvider).isPro;

    ref.listen<MolkkyState>(molkkyProvider, (prev, next) {
      if (next.isGameOver && !(prev?.isGameOver ?? false) && !_resultShown) {
        _resultShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _onGameOver(next);
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _tryAbandon();
      },
      child: Scaffold(
        backgroundColor: context.bgColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _tryAbandon,
          ),
          title: const Text('🪵  Mölkky'),
          actions: [
            IconButton(
              icon: Icon(
                Icons.undo_rounded,
                color: state.canUndo && !state.isGameOver
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
              tooltip: 'Annuler le dernier lancer',
              onPressed: state.canUndo && !state.isGameOver
                  ? () {
                      ref.read(molkkyProvider.notifier).undo();
                      setState(() => _throwMode = null);
                    }
                  : null,
            ),
            IconButton(
              icon: Icon(Icons.help_outline_rounded),
              tooltip: 'Règles du Mölkky',
              onPressed: _showRules,
            ),
          ],
        ),
        body: Column(
          children: [
            // Panneaux équipes
            Expanded(
              child: Row(
                children: [
                  _TeamPanel(
                    team: state.teams[0],
                    isActive: !state.isGameOver &&
                        state.currentTeamIndex == 0,
                    color: AppColors.primary,
                  ),
                  Container(
                    width: 1,
                    margin: EdgeInsets.symmetric(vertical: 32),
                    color: context.surfaceColor,
                  ),
                  _TeamPanel(
                    team: state.teams[1],
                    isActive: !state.isGameOver &&
                        state.currentTeamIndex == 1,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),

            // Indicateur de tour + interface de saisie
            if (!state.isGameOver) ...[
              _TurnIndicator(
                teamName: state.teams[state.currentTeamIndex].name,
                color: state.currentTeamIndex == 0
                    ? AppColors.primary
                    : AppColors.accent,
              ),
              _ThrowInput(
                selectedMode: _throwMode,
                onModeSelected: (mode) => setState(() => _throwMode = mode),
                onMiss: () {
                  ref.read(molkkyProvider.notifier).recordMiss();
                  setState(() => _throwMode = null);
                },
                onThrow: (points) {
                  ref.read(molkkyProvider.notifier).recordThrow(points);
                  setState(() => _throwMode = null);
                },
              ),
            ],

            // Bannière pub pour les utilisateurs gratuits
            if (!isPro) const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  // ─── Fin de partie ───────────────────────────────────────────────────────────

  Future<void> _onGameOver(MolkkyState state) async {
    final config = ref.read(gameConfigProvider);
    if (config != null) {
      await ref.read(historyProvider.notifier).addMatch(MatchRecord(
            gameTypeId: GameType.molkky.name,
            team1Name: state.teams[0].name,
            team2Name: state.teams[1].name,
            score1: state.teams[0].score,
            score2: state.teams[1].score,
            playedAt: DateTime.now(),
          ));
    }
    await _checkAndRequestReview();
    if (mounted) _showResultDialog(state);
  }

  Future<void> _checkAndRequestReview() async {
    final prefs = await SharedPreferences.getInstance();
    final completedGames = (prefs.getInt('completed_games') ?? 0) + 1;
    await prefs.setInt('completed_games', completedGames);
    if (completedGames == 3) {
      final lastReview = prefs.getInt('last_review_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const fourWeeks = 28 * 24 * 60 * 60 * 1000;
      if (now - lastReview > fourWeeks) {
        final inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
          await prefs.setInt('last_review_timestamp', now);
        }
      }
    }
  }

  void _showResultDialog(MolkkyState state) {
    final winnerId = state.winnerId;
    final winnerName =
        winnerId != null ? state.teams[winnerId].name : null;
    final isElim = state.teams.any((t) => t.isEliminated);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              winnerName != null ? '🏆' : '🤝',
              style: TextStyle(fontSize: 56),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              winnerName != null
                  ? (isElim ? 'Élimination !' : 'Victoire !')
                  : 'Match nul !',
              style: TextStyle(
                color: context.textColor,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            if (winnerName != null) ...[
              SizedBox(height: 8),
              Text(
                winnerName,
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (isElim)
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '3 ratés consécutifs',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
            ],
            SizedBox(height: 20),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.teams[0].score}  —  ${state.teams[1].score}',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resultShown = false;
              final config = ref.read(gameConfigProvider);
              if (config != null) {
                ref.read(molkkyProvider.notifier).init(config.teamNames);
              }
              setState(() => _throwMode = null);
            },
            child: Text(
              'Rejouer',
              style: TextStyle(color: AppColors.accent),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/home');
            },
            child: Text("Retour à l'accueil"),
          ),
        ],
      ),
    );
  }

  // ─── Dialog règles ────────────────────────────────────────────────────────────

  void _showRules() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '🪵  Règles du Mölkky',
          style: TextStyle(color: context.textColor),
          textAlign: TextAlign.center,
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RuleItem(
              icon: '1️⃣',
              text: '1 quille tombée → score = son numéro (1 à 12)',
            ),
            _RuleItem(
              icon: '💥',
              text:
                  '2+ quilles tombées → score = nombre de quilles renversées',
            ),
            _RuleItem(
              icon: '🎯',
              text: 'Objectif : atteindre exactement 50 points',
            ),
            _RuleItem(
              icon: '↩️',
              text: 'Dépasser 50 → le score retombe à 25',
            ),
            _RuleItem(
              icon: '❌',
              text: '3 ratés consécutifs → équipe éliminée',
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(minimumSize: Size(120, 44)),
            child: Text('Compris'),
          ),
        ],
      ),
    );
  }

  // ─── Abandon ─────────────────────────────────────────────────────────────────

  Future<void> _tryAbandon() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Abandonner ?',
            style: TextStyle(color: context.textColor)),
        content: const Text(
          'La partie en cours ne sera pas sauvegardée.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuer',
                style: TextStyle(color: AppColors.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abandonner',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if ((confirm ?? false) && mounted) context.go('/home');
  }
}

// ─── Panneau d'une équipe ─────────────────────────────────────────────────────

class _TeamPanel extends StatelessWidget {
  final MolkkyTeam team;
  final bool isActive;
  final Color color;

  const _TeamPanel({
    required this.team,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedOpacity(
        opacity: team.isEliminated ? 0.35 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Nom de l'équipe avec indicateur de tour
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive
                      ? color.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isActive
                      ? Border.all(color: color.withValues(alpha: 0.5))
                      : null,
                ),
                child: Text(
                  team.name,
                  style: TextStyle(
                    color: isActive ? color : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 6),

              // Score
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${team.score}',
                  style: TextStyle(
                    color: team.score == kMolkkyTarget
                        ? AppColors.success
                        : (isActive ? color : AppColors.textSecondary),
                    fontSize: 84,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              SizedBox(height: 6),

              // Barre de progression vers 50
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: (team.score / kMolkkyTarget).clamp(0.0, 1.0),
                    backgroundColor: context.surfaceColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      team.score == kMolkkyTarget
                          ? AppColors.success
                          : color,
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${team.score} / $kMolkkyTarget',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 10),
              ),
              const SizedBox(height: 12),

              // Compteur de ratés (3 pastilles)
              _MissDots(
                misses: team.consecutiveMisses,
                isEliminated: team.isEliminated,
              ),

              // Alerte 2 ratés consécutifs
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: team.consecutiveMisses == 2 && !team.isEliminated
                    ? const Padding(
                        key: ValueKey('warn'),
                        padding: EdgeInsets.only(top: 5),
                        child: Text(
                          '⚠️ Dernier essai !',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('no-warn')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pastilles de ratés ───────────────────────────────────────────────────────

class _MissDots extends StatelessWidget {
  final int misses;
  final bool isEliminated;

  const _MissDots({required this.misses, required this.isEliminated});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(kMolkkyMaxMisses, (i) {
        final filled = i < misses;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppColors.error : Colors.transparent,
              border: Border.all(
                color:
                    filled ? AppColors.error : AppColors.textSecondary,
                width: 1.5,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Indicateur de tour ───────────────────────────────────────────────────────

class _TurnIndicator extends StatelessWidget {
  final String teamName;
  final Color color;

  _TurnIndicator({required this.teamName, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            'Tour de : $teamName',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Interface de saisie du lancer ────────────────────────────────────────────

class _ThrowInput extends StatelessWidget {
  final _ThrowMode? selectedMode;
  final void Function(_ThrowMode?) onModeSelected;
  final VoidCallback onMiss;
  final void Function(int) onThrow;

  _ThrowInput({
    required this.selectedMode,
    required this.onModeSelected,
    required this.onMiss,
    required this.onThrow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          top: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Boutons de mode
          Row(
            children: [
              // Raté (action directe)
              Expanded(
                child: GestureDetector(
                  onTap: onMiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppColors.error.withValues(alpha: 0.45)),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('❌', style: TextStyle(fontSize: 14)),
                        SizedBox(height: 2),
                        Text(
                          'Raté',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 1 quille (toggle → grille 1-12)
              Expanded(
                child: _ModeToggleButton(
                  label: '1 quille',
                  icon: '🎯',
                  selected: selectedMode == _ThrowMode.onePin,
                  color: AppColors.primary,
                  onTap: () => onModeSelected(
                    selectedMode == _ThrowMode.onePin
                        ? null
                        : _ThrowMode.onePin,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Plusieurs quilles (toggle → grille 2-12)
              Expanded(
                child: _ModeToggleButton(
                  label: 'Plusieurs',
                  icon: '💥',
                  selected: selectedMode == _ThrowMode.multiplePins,
                  color: AppColors.accent,
                  onTap: () => onModeSelected(
                    selectedMode == _ThrowMode.multiplePins
                        ? null
                        : _ThrowMode.multiplePins,
                  ),
                ),
              ),
            ],
          ),

          // Grille de nombres
          if (selectedMode != null) ...[
            const SizedBox(height: 10),
            _NumberGrid(
              mode: selectedMode!,
              onNumber: onThrow,
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  final String label;
  final String icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  _ModeToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : context.bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Grille de numéros ────────────────────────────────────────────────────────

class _NumberGrid extends StatelessWidget {
  final _ThrowMode mode;
  final void Function(int) onNumber;

  const _NumberGrid({required this.mode, required this.onNumber});

  @override
  Widget build(BuildContext context) {
    final isOnePin = mode == _ThrowMode.onePin;
    final numbers = isOnePin
        ? List.generate(12, (i) => i + 1) // 1 à 12
        : List.generate(11, (i) => i + 2); // 2 à 12
    final color = isOnePin ? AppColors.primary : AppColors.accent;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: numbers.map((n) {
        return GestureDetector(
          onTap: () => onNumber(n),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
            ),
            child: Center(
              child: Text(
                '$n',
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Item règle ───────────────────────────────────────────────────────────────

class _RuleItem extends StatelessWidget {
  final String icon;
  final String text;

  const _RuleItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: TextStyle(fontSize: 16)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.textColor,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bannière AdMob (copie locale, gestion plateforme intégrée) ───────────────

