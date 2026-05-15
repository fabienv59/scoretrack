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

class CustomGameScreen extends ConsumerStatefulWidget {
  const CustomGameScreen({super.key});

  @override
  ConsumerState<CustomGameScreen> createState() => _CustomGameScreenState();
}

class _CustomGameScreenState extends ConsumerState<CustomGameScreen> {
  final _gameNameController = TextEditingController();
  final _targetController = TextEditingController();
  int _teamCount = 2;
  CountMode _countMode = CountMode.cumul;
  final List<TextEditingController> _teamControllers = List.generate(
    4,
    (i) => TextEditingController(text: 'Équipe ${i + 1}'),
  );

  @override
  void dispose() {
    _gameNameController.dispose();
    _targetController.dispose();
    for (final c in _teamControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _startGame() {
    final gameName = _gameNameController.text.trim().isEmpty
        ? 'Mon jeu'
        : _gameNameController.text.trim();
    final target = int.tryParse(_targetController.text.trim()) ?? 0;
    final teamNames = List.generate(
      _teamCount,
      (i) => _teamControllers[i].text.trim().isEmpty
          ? 'Équipe ${i + 1}'
          : _teamControllers[i].text.trim(),
    );

    ref.read(gameConfigProvider.notifier).setConfig(GameConfig(
          gameType: GameType.custom,
          teamNames: teamNames,
          targetScore: target,
          countMode: _countMode,
          customLabel: gameName,
        ));
    ref.read(scoreProvider.notifier).startGame(
          teamCount: _teamCount,
          targetScore: target,
        );
    context.push('/game');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('🎮  Jeu personnalisé'),
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
            _sectionLabel('NOM DU JEU'),
            const SizedBox(height: 12),
            TextField(
              controller: _gameNameController,
              style: const TextStyle(color: AppColors.textPrimary),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ex : Belote maison, Rami…',
                prefixIcon: Icon(Icons.gamepad_outlined, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 28),
            _sectionLabel('NOMBRE D\'ÉQUIPES'),
            const SizedBox(height: 12),
            Row(
              children: [2, 3, 4].map((n) {
                final selected = _teamCount == n;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: n < 4 ? 10 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _teamCount = n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$n',
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            _sectionLabel('NOMS DES ÉQUIPES'),
            const SizedBox(height: 12),
            ...List.generate(_teamCount, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _teamControllers[i],
                  style: const TextStyle(color: AppColors.textPrimary),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Équipe ${i + 1}',
                    prefixIcon: const Icon(Icons.group_outlined,
                        color: AppColors.accent),
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            _sectionLabel('CONFIGURATION'),
            const SizedBox(height: 12),
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
            const SizedBox(height: 20),
            const Text(
              'Mode de comptage',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                mode.description,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
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
