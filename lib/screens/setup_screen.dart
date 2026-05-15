import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/count_mode.dart';
import '../models/darts_variant.dart';
import '../models/game_config.dart';
import '../models/game_type.dart';
import '../providers/game_config_provider.dart';
import '../providers/score_provider.dart';
import '../theme.dart';

class SetupScreen extends ConsumerStatefulWidget {
  final String gameId;

  const SetupScreen({super.key, required this.gameId});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  late final GameType _gameType;
  final _team1Controller = TextEditingController(text: 'Équipe 1');
  final _team2Controller = TextEditingController(text: 'Équipe 2');
  late final TextEditingController _targetController;
  CountMode _countMode = CountMode.cumul;
  DartsVariant _dartsVariant = DartsVariant.darts501;
  int _dartsRounds = 8;

  @override
  void initState() {
    super.initState();
    _gameType = GameType.fromId(widget.gameId);
    _targetController = TextEditingController(
      text: _gameType.targetScore > 0 ? '${_gameType.targetScore}' : '',
    );
  }

  @override
  void dispose() {
    _team1Controller.dispose();
    _team2Controller.dispose();
    _targetController.dispose();
    super.dispose();
  }

  bool get _isMolkky => _gameType == GameType.molkky;
  bool get _isVolleyball => _gameType == GameType.volleyball;
  bool get _isDarts => _gameType == GameType.darts;
  // Jeux avec règles fixes : pas de config manuelle du score limite
  bool get _hasFixedRules => _isMolkky || _isVolleyball;

  int get _effectiveTarget =>
      int.tryParse(_targetController.text.trim()) ?? 0;

  void _startGame() {
    final name1 = _team1Controller.text.trim().isEmpty
        ? 'Équipe 1'
        : _team1Controller.text.trim();
    final name2 = _team2Controller.text.trim().isEmpty
        ? 'Équipe 2'
        : _team2Controller.text.trim();

    if (_isVolleyball) {
      context.push(
        '/game/volleyball',
        extra: {'teamA': name1, 'teamB': name2},
      );
      return;
    }

    if (_isDarts) {
      ref.read(gameConfigProvider.notifier).setConfig(GameConfig(
            gameType: _gameType,
            teamNames: [name1, name2],
            targetScore: 0,
            dartsVariant: _dartsVariant,
            dartsRounds: _dartsRounds,
          ));
      context.push('/darts');
      return;
    }

    ref.read(gameConfigProvider.notifier).setConfig(GameConfig(
          gameType: _gameType,
          teamNames: [name1, name2],
          targetScore: _isMolkky ? 50 : _effectiveTarget,
          countMode: _countMode,
        ));

    if (_isMolkky) {
      context.push('/molkky');
    } else {
      ref.read(scoreProvider.notifier).startGame(
            teamCount: 2,
            targetScore: _effectiveTarget,
          );
      context.push('/game');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${_gameType.emoji}  ${_gameType.label}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _sectionLabel('ÉQUIPES'),
            const SizedBox(height: 12),
            TextField(
              controller: _team1Controller,
              style: const TextStyle(color: AppColors.textPrimary),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Équipe 1',
                prefixIcon: const Icon(Icons.person, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear,
                      color: AppColors.textSecondary, size: 18),
                  onPressed: () => _team1Controller.clear(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _team2Controller,
              style: const TextStyle(color: AppColors.textPrimary),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Équipe 2',
                prefixIcon:
                    const Icon(Icons.person_outline, color: AppColors.accent),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear,
                      color: AppColors.textSecondary, size: 18),
                  onPressed: () => _team2Controller.clear(),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _sectionLabel('CONFIGURATION'),
            const SizedBox(height: 12),

            // ── Jeux à règles fixes ───────────────────────────────────────
            if (_hasFixedRules) ...[
              _RulesCard(gameType: _gameType),
            ] else if (_isDarts) ...[
              // ── Variantes fléchettes ──────────────────────────────────────
              _DartsVariantSelector(
                selected: _dartsVariant,
                onSelect: (v) => setState(() => _dartsVariant = v),
              ),
              if (_dartsVariant == DartsVariant.countUp) ...[
                const SizedBox(height: 20),
                _sectionLabel('NOMBRE DE MANCHES'),
                const SizedBox(height: 10),
                _RoundsSelector(
                  rounds: _dartsRounds,
                  onChanged: (r) => setState(() => _dartsRounds = r),
                ),
              ],
            ] else ...[
              // ── Score limite ─────────────────────────────────────────────
              TextField(
                controller: _targetController,
                style: const TextStyle(color: AppColors.textPrimary),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Score limite (0 = score libre)',
                  prefixIcon:
                      Icon(Icons.flag_outlined, color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 24),
              // ── Mode de comptage ─────────────────────────────────────────
              const Text(
                'Mode de comptage',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: CountMode.values.map((mode) {
                  final selected = _countMode == mode;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: mode == CountMode.cumul ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _countMode = mode),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.2),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                mode.label,
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mode.description,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _startGame,
              child: const Text('Démarrer la partie'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      );
}

// ─── Sélecteur de variante fléchettes ────────────────────────────────────────

class _DartsVariantSelector extends StatelessWidget {
  final DartsVariant selected;
  final void Function(DartsVariant) onSelect;

  const _DartsVariantSelector({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: DartsVariant.values.map((v) {
            final isSelected = v == selected;
            return GestureDetector(
              onTap: () => onSelect(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: (MediaQuery.of(context).size.width - 48 - 10) / 2,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.2),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.label,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v.subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Sélecteur de nombre de manches (Count Up) ────────────────────────────────

class _RoundsSelector extends StatelessWidget {
  final int rounds;
  final void Function(int) onChanged;

  const _RoundsSelector({required this.rounds, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: rounds > 3 ? () => onChanged(rounds - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: AppColors.primary,
          iconSize: 28,
        ),
        const SizedBox(width: 16),
        Column(
          children: [
            Text(
              '$rounds',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text(
              'manches',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: rounds < 20 ? () => onChanged(rounds + 1) : null,
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: AppColors.primary,
          iconSize: 28,
        ),
      ],
    );
  }
}

// ─── Carte de règles pour les jeux à moteur dédié ─────────────────────────────

/// Affiche un résumé des règles fixes selon le jeu (Mölkky, Volleyball…).
/// Remplace les champs de config quand le jeu a ses propres règles intégrées.
class _RulesCard extends StatelessWidget {
  final GameType gameType;

  const _RulesCard({required this.gameType});

  @override
  Widget build(BuildContext context) {
    final rules = _rulesFor(gameType);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: rules
            .map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Text(r.$1, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.$2,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 13),
                      ),
                    ),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  /// Retourne la liste des règles (emoji, texte) selon le jeu.
  List<(String, String)> _rulesFor(GameType type) {
    switch (type) {
      case GameType.volleyball:
        return [
          ('🏐', 'Best of 5 sets — 3 sets gagnants'),
          ('🎯', 'Sets 1-4 : 25 pts minimum, 2 pts d\'écart'),
          ('⚡', 'Set 5 (tie-break) : 15 pts, 2 pts d\'écart'),
        ];
      case GameType.molkky:
        return [
          ('🎯', 'Objectif : exactement 50 points'),
          ('↩️', 'Dépasser 50 → score retombe à 25'),
          ('❌', '3 ratés consécutifs → élimination'),
        ];
      default:
        return [];
    }
  }
}
