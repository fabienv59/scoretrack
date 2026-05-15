import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/ad_config.dart';
import '../../models/darts_variant.dart';
import '../../models/game_type.dart';
import '../../models/match_record.dart';
import '../../providers/darts_provider.dart';
import '../../providers/game_config_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/pro_provider.dart';
import '../../theme.dart';

// ─── Écran principal ──────────────────────────────────────────────────────────

class DartsGameScreen extends ConsumerStatefulWidget {
  const DartsGameScreen({super.key});

  @override
  ConsumerState<DartsGameScreen> createState() => _DartsGameScreenState();
}

class _DartsGameScreenState extends ConsumerState<DartsGameScreen> {
  String _entry = '';
  bool _doubleFinish = false;
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
    if (config == null || config.dartsVariant == null) {
      context.go('/home');
      return;
    }
    ref.read(dartsProvider.notifier).init(
          config.teamNames,
          config.dartsVariant!,
          totalRounds: config.dartsRounds,
        );
    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dartsProvider);
    final isPro = ref.watch(proProvider).isPro;

    ref.listen<DartsState>(dartsProvider, (prev, next) {
      if (next.isGameOver && !(prev?.isGameOver ?? false) && !_resultShown) {
        _resultShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _onGameOver(next);
        });
      }
      if (next.isBust && !(prev?.isBust ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'BUST ! Volée annulée — score inchangé',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              duration: Duration(seconds: 2),
              backgroundColor: AppColors.error,
            ),
          );
          ref.read(dartsProvider.notifier).clearBust();
        });
      }
    });

    final variant = state.variant;
    final appBarTitle = switch (variant) {
      DartsVariant.darts501 => '🎯  501 Double Out',
      DartsVariant.darts301 => '🎯  301 Double Out',
      DartsVariant.countUp => '🎯  Count Up',
      DartsVariant.roundTheClock => "🎯  L'Horloge",
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _tryAbandon();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _tryAbandon,
          ),
          title: Text(appBarTitle),
          actions: [
            IconButton(
              icon: Icon(
                Icons.undo_rounded,
                color: state.canUndo && !state.isGameOver
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ),
              tooltip: 'Annuler la dernière volée',
              onPressed: state.canUndo && !state.isGameOver
                  ? () {
                      ref.read(dartsProvider.notifier).undo();
                      setState(() {
                        _entry = '';
                        _doubleFinish = false;
                      });
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: 'Règles',
              onPressed: () => _showRules(variant),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  _PlayerPanel(
                    player: state.players[0],
                    isActive: !state.isGameOver && state.currentPlayerIndex == 0,
                    variant: variant,
                    totalRounds: state.totalRounds,
                    color: AppColors.primary,
                  ),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 32),
                    color: AppColors.surface,
                  ),
                  _PlayerPanel(
                    player: state.players[1],
                    isActive: !state.isGameOver && state.currentPlayerIndex == 1,
                    variant: variant,
                    totalRounds: state.totalRounds,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
            if (!state.isGameOver)
              variant == DartsVariant.roundTheClock
                  ? _RtcInput(
                      teamName: state.currentPlayer.name,
                      color: state.currentPlayerIndex == 0
                          ? AppColors.primary
                          : AppColors.accent,
                      onZones: (z) =>
                          ref.read(dartsProvider.notifier).recordRtcVolley(z),
                    )
                  : _VolleyInput(
                      entry: _entry,
                      doubleFinish: _doubleFinish,
                      showDoubleToggle: variant.isCountdown,
                      onDigit: (d) => setState(() {
                        final candidate = _entry + d;
                        if ((int.tryParse(candidate) ?? 0) <= 180) {
                          _entry = candidate;
                        }
                      }),
                      onBackspace: () => setState(
                          () => _entry = _entry.isEmpty
                              ? ''
                              : _entry.substring(0, _entry.length - 1)),
                      onDoubleToggle: (v) =>
                          setState(() => _doubleFinish = v),
                      onValidate: _validate,
                    ),
            if (!isPro) const _BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  void _validate() {
    final points = int.tryParse(_entry) ?? 0;
    ref.read(dartsProvider.notifier).recordVolley(
          points,
          doubleFinish: _doubleFinish,
        );
    setState(() {
      _entry = '';
      _doubleFinish = false;
    });
  }

  // ─── Fin de partie ───────────────────────────────────────────────────────────

  Future<void> _onGameOver(DartsState state) async {
    final config = ref.read(gameConfigProvider);
    if (config != null) {
      await ref.read(historyProvider.notifier).addMatch(MatchRecord(
            gameTypeId: GameType.darts.name,
            team1Name: state.players[0].name,
            team2Name: state.players[1].name,
            score1: state.players[0].score,
            score2: state.players[1].score,
            playedAt: DateTime.now(),
            winnerName: state.winnerId != null
                ? state.players[state.winnerId!].name
                : null,
          ));
    }
    await _checkAndRequestReview();
    if (mounted) _showResultDialog(state);
  }

  Future<void> _checkAndRequestReview() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt('completed_games') ?? 0) + 1;
    await prefs.setInt('completed_games', count);
    if (count == 3) {
      final last = prefs.getInt('last_review_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const fourWeeks = 28 * 24 * 60 * 60 * 1000;
      if (now - last > fourWeeks) {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
          await prefs.setInt('last_review_timestamp', now);
        }
      }
    }
  }

  void _showResultDialog(DartsState state) {
    final winnerId = state.winnerId;
    final winnerName =
        winnerId != null ? state.players[winnerId].name : null;
    final score1 = _displayScore(state, 0);
    final score2 = _displayScore(state, 1);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              winnerName != null ? '🏆' : '🤝',
              style: const TextStyle(fontSize: 56),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              winnerName != null ? 'Victoire !' : 'Égalité !',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            if (winnerName != null) ...[
              const SizedBox(height: 8),
              Text(
                winnerName,
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$score1  —  $score2',
                style: const TextStyle(
                  color: AppColors.textPrimary,
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
              if (config?.dartsVariant != null) {
                ref.read(dartsProvider.notifier).init(
                      config!.teamNames,
                      config.dartsVariant!,
                      totalRounds: config.dartsRounds,
                    );
              }
              setState(() {
                _entry = '';
                _doubleFinish = false;
              });
            },
            child: const Text('Rejouer',
                style: TextStyle(color: AppColors.accent)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/home');
            },
            child: const Text("Retour à l'accueil"),
          ),
        ],
      ),
    );
  }

  String _displayScore(DartsState state, int idx) {
    final p = state.players[idx];
    if (state.variant == DartsVariant.roundTheClock) {
      return '${p.score} zones';
    }
    return '${p.score}';
  }

  // ─── Dialog règles ────────────────────────────────────────────────────────────

  void _showRules(DartsVariant variant) {
    final rules = switch (variant) {
      DartsVariant.darts501 || DartsVariant.darts301 => [
          ('🎯', 'Chaque volée : saisir le total des 3 fléchettes (0-180)'),
          ('🏁', 'La dernière fléchette doit toucher une zone double (D1-D20 ou bull)'),
          ('💥', 'BUST : si le score passe sous 0, reste à 1, ou finish sans double'),
          ('🏆', 'Gagner : atteindre exactement 0 en double'),
        ],
      DartsVariant.countUp => [
          ('🎯', 'Chaque volée : saisir le total des 3 fléchettes (0-180)'),
          ('📈', 'Le score monte — pas de bust possible'),
          ('🏁', 'Fin après ${ref.read(dartsProvider).totalRounds} manches chacun'),
          ('🏆', 'Gagner : avoir le score le plus élevé'),
        ],
      DartsVariant.roundTheClock => [
          ('🎯', 'Chaque tour : 3 fléchettes pour toucher la zone cible'),
          ('🔢', 'Progression : 1 → 2 → … → 20 → Bull'),
          ('✅', 'Indiquer combien de zones touchées dans la volée (0-3)'),
          ('🏆', 'Gagner : premier à toucher le Bull'),
        ],
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '🎯  ${variant.label}',
          style: const TextStyle(color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: rules
              .map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.$1, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            r.$2,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style:
                ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
            child: const Text('Compris'),
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
        title: const Text('Abandonner ?',
            style: TextStyle(color: AppColors.textPrimary)),
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

// ─── Panneau joueur ───────────────────────────────────────────────────────────

class _PlayerPanel extends StatelessWidget {
  final DartsPlayer player;
  final bool isActive;
  final DartsVariant variant;
  final int totalRounds;
  final Color color;

  const _PlayerPanel({
    required this.player,
    required this.isActive,
    required this.variant,
    required this.totalRounds,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Nom + indicateur de tour
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
                player.name,
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
            const SizedBox(height: 8),

            if (variant == DartsVariant.roundTheClock) ...[
              _RtcPlayerContent(player: player, isActive: isActive, color: color),
            ] else ...[
              _ScorePlayerContent(
                player: player,
                isActive: isActive,
                variant: variant,
                totalRounds: totalRounds,
                color: color,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScorePlayerContent extends StatelessWidget {
  final DartsPlayer player;
  final bool isActive;
  final DartsVariant variant;
  final int totalRounds;
  final Color color;

  const _ScorePlayerContent({
    required this.player,
    required this.isActive,
    required this.variant,
    required this.totalRounds,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isCountdown = variant.isCountdown;
    final startScore = variant.startScore;

    return Column(
      children: [
        Text(
          isCountdown ? 'Reste' : 'Score',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${player.score}',
            style: TextStyle(
              color: isActive ? color : AppColors.textSecondary,
              fontSize: 80,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        if (isCountdown && startScore > 0) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: 1.0 - (player.score / startScore).clamp(0.0, 1.0),
                backgroundColor: AppColors.surface,
                valueColor: AlwaysStoppedAnimation<Color>(
                  player.score == 0 ? AppColors.success : color,
                ),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${startScore - player.score} pts marqués',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
        if (variant == DartsVariant.countUp) ...[
          const SizedBox(height: 6),
          Text(
            'Manche ${player.roundsPlayed}/$totalRounds',
            style: TextStyle(
              color: isActive ? color : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: (player.roundsPlayed / totalRounds).clamp(0.0, 1.0),
                backgroundColor: AppColors.surface,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RtcPlayerContent extends StatelessWidget {
  final DartsPlayer player;
  final bool isActive;
  final Color color;

  const _RtcPlayerContent({
    required this.player,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = player.score >= kRtcTotalZones;
    final target =
        isDone ? 'Fini !' : kRtcZoneLabels[player.score];

    return Column(
      children: [
        Text(
          isDone ? 'Terminé' : 'Vise',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            target,
            style: TextStyle(
              color: isDone
                  ? AppColors.success
                  : (isActive ? color : AppColors.textSecondary),
              fontSize: 72,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (player.score / kRtcTotalZones).clamp(0.0, 1.0),
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? AppColors.success : color,
              ),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${player.score} / $kRtcTotalZones zones',
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}

// ─── Saisie volée (countdown / countUp) ──────────────────────────────────────

class _VolleyInput extends StatelessWidget {
  final String entry;
  final bool doubleFinish;
  final bool showDoubleToggle;
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final void Function(bool) onDoubleToggle;
  final VoidCallback onValidate;

  const _VolleyInput({
    required this.entry,
    required this.doubleFinish,
    required this.showDoubleToggle,
    required this.onDigit,
    required this.onBackspace,
    required this.onDoubleToggle,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = entry.isEmpty ? '0' : entry;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Affichage de la saisie
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              displayValue,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Pavé numérique
          _Keypad(onDigit: onDigit, onBackspace: onBackspace),
          const SizedBox(height: 8),

          // Toggle "Double final" (uniquement pour les variantes countdown)
          if (showDoubleToggle)
            GestureDetector(
              onTap: () => onDoubleToggle(!doubleFinish),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: doubleFinish
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: doubleFinish
                        ? AppColors.success
                        : AppColors.primary.withValues(alpha: 0.3),
                    width: doubleFinish ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      doubleFinish
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: doubleFinish
                          ? AppColors.success
                          : AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dernière fléchette = double',
                      style: TextStyle(
                        color: doubleFinish
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (showDoubleToggle) const SizedBox(height: 8),

          // Bouton Valider
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onValidate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Valider la volée',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pavé numérique ───────────────────────────────────────────────────────────

class _Keypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const _Keypad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: row.map((key) {
              final isBackspace = key == '⌫';
              final isEmpty = key.isEmpty;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: row.indexOf(key) > 0 ? 6 : 0,
                  ),
                  child: isEmpty
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: isBackspace
                              ? onBackspace
                              : () => onDigit(key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 80),
                            height: 44,
                            decoration: BoxDecoration(
                              color: isBackspace
                                  ? AppColors.error.withValues(alpha: 0.1)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isBackspace
                                    ? AppColors.error.withValues(alpha: 0.4)
                                    : AppColors.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                key,
                                style: TextStyle(
                                  color: isBackspace
                                      ? AppColors.error
                                      : AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Saisie RoundTheClock ─────────────────────────────────────────────────────

class _RtcInput extends StatelessWidget {
  final String teamName;
  final Color color;
  final void Function(int) onZones;

  const _RtcInput({
    required this.teamName,
    required this.color,
    required this.onZones,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tour de $teamName — zones touchées :',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => onZones(i),
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$i',
                            style: TextStyle(
                              color: color,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            i == 1 ? 'zone' : 'zones',
                            style: TextStyle(
                              color: color.withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Bannière AdMob ───────────────────────────────────────────────────────────

class _BannerAdWidget extends StatefulWidget {
  const _BannerAdWidget();

  @override
  State<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<_BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    if (_supported) _loadAd();
  }

  void _loadAd() {
    _ad = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported || !_loaded || _ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: _ad!.size.width.toDouble(),
        height: _ad!.size.height.toDouble(),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
