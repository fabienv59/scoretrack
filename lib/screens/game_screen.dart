import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/ad_config.dart';
import '../models/count_mode.dart';
import '../models/game_config.dart';
import '../models/match_record.dart';
import '../providers/game_config_provider.dart';
import '../providers/history_provider.dart';
import '../providers/pro_provider.dart';
import '../providers/score_provider.dart';
import '../theme.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _resultShown = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gameConfigProvider);
    if (config == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => context.go('/home'));
      return const Scaffold(backgroundColor: AppColors.background);
    }

    ref.listen<ScoreState>(scoreProvider, (prev, next) {
      if (next.isGameOver && !(prev?.isGameOver ?? false) && !_resultShown) {
        _resultShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _saveAndShowResult(config, next);
        });
      }
    });

    final score = ref.watch(scoreProvider);
    final isPro = ref.watch(proProvider).isPro;

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
          title: Text('${config.displayEmoji}  ${config.displayLabel}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: 'Annuler la dernière saisie',
              color: score.canUndo ? AppColors.accent : AppColors.textSecondary,
              onPressed: score.canUndo && !score.isGameOver
                  ? () => ref.read(scoreProvider.notifier).undo()
                  : null,
            ),
            if (!score.isGameOver)
              TextButton(
                onPressed: () => ref.read(scoreProvider.notifier).endGame(),
                child: const Text(
                  'Terminer',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            if (config.targetScore > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Objectif : ${config.targetScore} pts',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            Expanded(
              child: config.teamCount <= 2
                  ? _TwoTeamLayout(
                      config: config,
                      score: score,
                      onAddPoints: (i, v) =>
                          ref.read(scoreProvider.notifier).addPoints(i, v),
                      onSetScore: (i, v) =>
                          ref.read(scoreProvider.notifier).setScore(i, v),
                    )
                  : _MultiTeamLayout(
                      config: config,
                      score: score,
                      onAddPoints: (i, v) =>
                          ref.read(scoreProvider.notifier).addPoints(i, v),
                      onSetScore: (i, v) =>
                          ref.read(scoreProvider.notifier).setScore(i, v),
                    ),
            ),
            if (!score.isGameOver)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: ElevatedButton(
                  onPressed: () =>
                      ref.read(scoreProvider.notifier).endGame(),
                  child: const Text('Terminer la partie'),
                ),
              ),
            // Bannière pub uniquement pour les utilisateurs gratuits
            if (!isPro) const _BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndShowResult(GameConfig config, ScoreState score) async {
    await ref.read(historyProvider.notifier).addMatch(MatchRecord(
          gameTypeId: config.gameType.name,
          team1Name: config.team1Name,
          team2Name: config.team2Name,
          score1: score.score1,
          score2: score.score2,
          playedAt: DateTime.now(),
        ));
    await _checkAndRequestReview();
    if (mounted) _showResultDialog(config, score);
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

  void _showResultDialog(GameConfig config, ScoreState score) {
    final winnerId = score.winnerId;
    final winner =
        winnerId != null && winnerId < config.teamNames.length
            ? config.teamNames[winnerId]
            : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(winner != null ? '🏆' : '🤝',
                style: const TextStyle(fontSize: 56),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              winner != null ? 'Victoire !' : 'Match nul !',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            if (winner != null) ...[
              const SizedBox(height: 8),
              Text(
                winner,
                style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
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
                score.scores.join('  —  '),
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/home');
            },
            child: const Text('Retour à l\'accueil'),
          ),
        ],
      ),
    );
  }

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

// ─── Bannière AdMob (auto-gérée, sans espace si non chargée) ──────────────────

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

// ─── Layout 2 équipes (côte à côte) ───────────────────────────────────────────

class _TwoTeamLayout extends StatelessWidget {
  final GameConfig config;
  final ScoreState score;
  final void Function(int, int) onAddPoints;
  final void Function(int, int) onSetScore;

  const _TwoTeamLayout({
    required this.config,
    required this.score,
    required this.onAddPoints,
    required this.onSetScore,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.primary, AppColors.accent];
    return Row(
      children: List.generate(2, (i) {
        final isWinner = score.isGameOver && score.winnerId == i;
        final isLoser = score.isGameOver &&
            score.winnerId != null &&
            score.winnerId != i;
        return Expanded(
          child: _ScorePanel(
            teamName: config.teamNames[i],
            score: score.scores[i],
            isWinner: isWinner,
            isLoser: isLoser,
            color: colors[i],
            countMode: config.countMode,
            disabled: score.isGameOver,
            onAddPoints: (v) => onAddPoints(i, v),
            onSetScore: (v) => onSetScore(i, v),
            onEditScore: () => _showScoreInput(context, i),
          ),
        );
      })
        ..insert(
          1,
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 40),
            color: AppColors.surface,
          ),
        ),
    );
  }

  void _showScoreInput(BuildContext context, int teamIndex) {
    showScoreInputDialog(context, config.teamNames[teamIndex],
        (val) => onSetScore(teamIndex, val));
  }
}

// ─── Layout 3-4 équipes (liste verticale) ─────────────────────────────────────

class _MultiTeamLayout extends StatelessWidget {
  final GameConfig config;
  final ScoreState score;
  final void Function(int, int) onAddPoints;
  final void Function(int, int) onSetScore;

  const _MultiTeamLayout({
    required this.config,
    required this.score,
    required this.onAddPoints,
    required this.onSetScore,
  });

  static const _teamColors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.success,
    Color(0xFFFFB347),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: config.teamCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final isWinner = score.isGameOver && score.winnerId == i;
        final isLoser = score.isGameOver &&
            score.winnerId != null &&
            score.winnerId != i;
        return _TeamRow(
          teamName: config.teamNames[i],
          score: score.scores[i],
          color: _teamColors[i % _teamColors.length],
          isWinner: isWinner,
          isLoser: isLoser,
          countMode: config.countMode,
          disabled: score.isGameOver,
          onAddPoints: (v) => onAddPoints(i, v),
          onSetScore: (v) => onSetScore(i, v),
          onEditScore: () => showScoreInputDialog(
              ctx, config.teamNames[i], (v) => onSetScore(i, v)),
        );
      },
    );
  }
}

// ─── Panel pour 2 équipes ──────────────────────────────────────────────────────

class _ScorePanel extends StatelessWidget {
  final String teamName;
  final int score;
  final bool isWinner;
  final bool isLoser;
  final Color color;
  final CountMode countMode;
  final bool disabled;
  final void Function(int) onAddPoints;
  final void Function(int) onSetScore;
  final VoidCallback onEditScore;

  const _ScorePanel({
    required this.teamName,
    required this.score,
    required this.isWinner,
    required this.isLoser,
    required this.color,
    required this.countMode,
    required this.disabled,
    required this.onAddPoints,
    required this.onSetScore,
    required this.onEditScore,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isLoser ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isWinner)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('🏆', style: TextStyle(fontSize: 28)),
              ),
            Text(
              teamName,
              style: TextStyle(
                color: isWinner ? AppColors.success : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: !disabled && countMode == CountMode.direct
                      ? onEditScore
                      : null,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: isWinner ? AppColors.success : color,
                      fontSize: 96,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                    child: Text('$score', textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!disabled) ...[
              if (countMode == CountMode.cumul) ...[
                _CumulButtons(color: color, onAdd: onAddPoints, big: true),
                const SizedBox(height: 12),
                _ScoreInputField(color: color, onSubmit: onAddPoints),
              ] else ...[
                _BigButton(
                  icon: Icons.edit_rounded,
                  color: color,
                  onTap: onEditScore,
                  label: 'Modifier',
                ),
                const SizedBox(height: 12),
                _ScoreInputField(color: color, onSubmit: onSetScore),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Rangée pour 3-4 équipes ───────────────────────────────────────────────────

class _TeamRow extends StatelessWidget {
  final String teamName;
  final int score;
  final Color color;
  final bool isWinner;
  final bool isLoser;
  final CountMode countMode;
  final bool disabled;
  final void Function(int) onAddPoints;
  final void Function(int) onSetScore;
  final VoidCallback onEditScore;

  const _TeamRow({
    required this.teamName,
    required this.score,
    required this.color,
    required this.isWinner,
    required this.isLoser,
    required this.countMode,
    required this.disabled,
    required this.onAddPoints,
    required this.onSetScore,
    required this.onEditScore,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isLoser ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWinner ? AppColors.success : color.withOpacity(0.3),
            width: isWinner ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (isWinner)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('🏆', style: TextStyle(fontSize: 20)),
                  ),
                Expanded(
                  child: Text(
                    teamName,
                    style: TextStyle(
                      color: isWinner ? AppColors.success : AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: !disabled && countMode == CountMode.direct
                      ? onEditScore
                      : null,
                  child: Text(
                    '$score',
                    style: TextStyle(
                      color: isWinner ? AppColors.success : color,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!disabled && countMode == CountMode.direct) ...[
                  const SizedBox(width: 16),
                  _SmallButton(
                      icon: Icons.edit_rounded, color: color, onTap: onEditScore),
                ],
              ],
            ),
            if (!disabled && countMode == CountMode.cumul) ...[
              const SizedBox(height: 12),
              _CumulButtons(color: color, onAdd: onAddPoints),
            ],
            if (!disabled) ...[
              const SizedBox(height: 12),
              _ScoreInputField(
                color: color,
                onSubmit: countMode == CountMode.cumul ? onAddPoints : onSetScore,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Boutons ───────────────────────────────────────────────────────────────────

class _BigButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? label;

  const _BigButton(
      {required this.icon,
      required this.color,
      required this.onTap,
      this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: label != null ? null : 76,
        height: label != null ? 56 : 76,
        padding:
            label != null ? const EdgeInsets.symmetric(horizontal: 16) : null,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4), width: 2),
        ),
        child: label != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 6),
                  Text(label!,
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              )
            : Icon(icon, color: color, size: 38),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

// ─── Boutons Cumul +1 à +6 ────────────────────────────────────────────────────

class _CumulButtons extends StatelessWidget {
  final Color color;
  final void Function(int) onAdd;
  final bool big;

  const _CumulButtons(
      {required this.color, required this.onAdd, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [1, 2, 3, 4, 5, 6]
          .map((v) => _ValueButton(
                value: v,
                color: color,
                big: big,
                onTap: () => onAdd(v),
              ))
          .toList(),
    );
  }
}

class _ValueButton extends StatelessWidget {
  final int value;
  final Color color;
  final bool big;
  final VoidCallback onTap;

  const _ValueButton(
      {required this.value,
      required this.color,
      required this.onTap,
      this.big = false});

  @override
  Widget build(BuildContext context) {
    final size = big ? 56.0 : 40.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(big ? 16 : 10),
          border: Border.all(color: color.withOpacity(0.4), width: big ? 2 : 1),
        ),
        child: Center(
          child: Text(
            '+$value',
            style: TextStyle(
              color: color,
              fontSize: big ? 18 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Champ de saisie numérique inline ─────────────────────────────────────────

class _ScoreInputField extends StatefulWidget {
  final Color color;
  final void Function(int) onSubmit;

  const _ScoreInputField({required this.color, required this.onSubmit});

  @override
  State<_ScoreInputField> createState() => _ScoreInputFieldState();
}

class _ScoreInputFieldState extends State<_ScoreInputField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final v = int.tryParse(_ctrl.text);
    if (v != null) {
      widget.onSubmit(v);
      _ctrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0',
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: widget.color.withOpacity(0.4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: widget.color.withOpacity(0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: widget.color, width: 2),
              ),
            ),
            onSubmitted: (_) => _confirm(),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _confirm,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('OK',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Dialog saisie de score (Direct mode) ─────────────────────────────────────

void showScoreInputDialog(
    BuildContext context, String teamName, void Function(int) onConfirm) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        teamName,
        style: const TextStyle(color: AppColors.textPrimary),
        textAlign: TextAlign.center,
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w900),
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          labelText: 'Nouveau score total',
          hintText: '0',
        ),
        onSubmitted: (val) {
          onConfirm(int.tryParse(val) ?? 0);
          Navigator.pop(ctx);
        },
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirm(int.tryParse(controller.text) ?? 0);
            Navigator.pop(ctx);
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
          child: const Text('Confirmer'),
        ),
      ],
    ),
  );
}
