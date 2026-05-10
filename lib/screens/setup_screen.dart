import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/count_mode.dart';
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

  int get _effectiveTarget =>
      int.tryParse(_targetController.text.trim()) ?? 0;

  void _startGame() {
    final name1 = _team1Controller.text.trim().isEmpty
        ? 'Équipe 1'
        : _team1Controller.text.trim();
    final name2 = _team2Controller.text.trim().isEmpty
        ? 'Équipe 2'
        : _team2Controller.text.trim();

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

  void _setDartsVariant(int score) {
    setState(() => _targetController.text = '$score');
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
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
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
                prefixIcon: const Icon(Icons.person_outline, color: AppColors.accent),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                  onPressed: () => _team2Controller.clear(),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _sectionLabel('CONFIGURATION'),
            const SizedBox(height: 12),

            // Mölkky : règles fixes, pas de config manuelle
            if (_isMolkky) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.3)),
                ),
                child: const Column(
                  children: [
                    Row(children: [
                      Text('🎯', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('Objectif : exactement 50 points',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13))),
                    ]),
                    SizedBox(height: 8),
                    Row(children: [
                      Text('↩️', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('Dépasser 50 → score retombe à 25',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13))),
                    ]),
                    SizedBox(height: 8),
                    Row(children: [
                      Text('❌', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('3 ratés consécutifs → élimination',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13))),
                    ]),
                  ],
                ),
              ),
            ] else ...[
              // Score limite
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
              // Variantes fléchettes
              if (_gameType == GameType.darts) ...[
                const SizedBox(height: 12),
                const Text(
                  'Variante rapide',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [301, 501, 701].map((v) {
                    final selected = _targetController.text == '$v';
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => _setDartsVariant(v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '$v',
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              // Mode de comptage
              const Text(
                'Mode de comptage',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                                ? AppColors.primary.withOpacity(0.15)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.primary.withOpacity(0.2),
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
