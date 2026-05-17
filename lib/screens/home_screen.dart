import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/game_type.dart';
import '../providers/pro_provider.dart';
import '../theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(proProvider).isPro;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(
                        text: 'Score',
                        style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: context.textColor,
                            letterSpacing: -1),
                      ),
                      TextSpan(
                        text: 'Track',
                        style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -1),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'par VanByte — Choisissez un jeu',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                itemCount: GameType.values.length,
                itemBuilder: (context, index) {
                  final game = GameType.values[index];
                  final isCustom = game == GameType.custom;
                  return _GameCard(
                    game: game,
                    locked: isCustom && !isPro,
                    onTap: () => _handleTap(context, ref, game, isPro),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(
      BuildContext context, WidgetRef ref, GameType game, bool isPro) {
    if (game == GameType.custom) {
      if (isPro) {
        context.push('/custom');
      } else {
        _showProDialog(context, ref);
      }
    } else {
      context.push('/setup/${game.name}');
    }
  }

  void _showProDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '🔒 Fonctionnalité Pro',
          style: TextStyle(color: context.textColor, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Créez des jeux avec un nom libre,\nde 2 à 4 équipes et vos propres règles.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('⭐', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ScoreTrack Pro',
                        style: TextStyle(
                            color: context.textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                      Text(
                        '1,99 € / an',
                        style: TextStyle(
                            color: AppColors.accent, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Plus tard',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(proProvider.notifier).purchasePro();
              Navigator.pop(ctx);
              context.push('/pro');
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size(140, 48),
            ),
            child: Text('Acheter'),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final GameType game;
  final bool locked;
  final VoidCallback onTap;

  _GameCard({
    required this.game,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: locked
                ? AppColors.textSecondary.withValues(alpha: 0.3)
                : AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GameIcon(game: game),
                SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    game.label,
                    style: TextStyle(
                      color: locked
                          ? AppColors.textSecondary
                          : context.textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    // Utilise le subtitle défini dans GameType
                    game.subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (locked)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('🔒',
                      style: TextStyle(fontSize: 14)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GameIcon extends StatelessWidget {
  final GameType game;
  const _GameIcon({required this.game});

  @override
  Widget build(BuildContext context) {
    final asset = game.assetImage;
    if (asset != null) {
      return Image.asset(
        asset,
        width: 40,
        height: 40,
        errorBuilder: (context, error, stackTrace) =>
            Text(game.emoji, style: const TextStyle(fontSize: 40)),
      );
    }
    return Text(game.emoji, style: const TextStyle(fontSize: 44));
  }
}
