import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/game_type.dart';
import '../models/match_record.dart';
import '../providers/pro_provider.dart';
import '../providers/stats_provider.dart';
import '../theme.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

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
              child: Text(
                'Statistiques',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Expanded(
              child: isPro ? const _ProStatsContent() : const _LockedOverlay(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Contenu Pro ───────────────────────────────────────────────────────────────

class _ProStatsContent extends ConsumerWidget {
  const _ProStatsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(allMatchesProvider);

    return matchesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(
        child: Text('Erreur: $e',
            style: const TextStyle(color: AppColors.error)),
      ),
      data: (matches) {
        if (matches.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('📊', style: TextStyle(fontSize: 64)),
                SizedBox(height: 16),
                Text(
                  'Aucune statistique',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Jouez des parties pour voir vos stats !',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }
        return _StatsBody(matches: matches);
      },
    );
  }
}

class _StatsBody extends StatelessWidget {
  final List<MatchRecord> matches;

  const _StatsBody({required this.matches});

  @override
  Widget build(BuildContext context) {
    final total = matches.length;
    final withWinner = matches.where((m) => m.winner != null).length;
    final draws = total - withWinner;

    final gameCounts = <String, int>{};
    for (final m in matches) {
      gameCounts[m.gameTypeId] = (gameCounts[m.gameTypeId] ?? 0) + 1;
    }
    final mostPlayedId = gameCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    final mostPlayed = GameType.fromId(mostPlayedId);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              _StatCard(value: '$total', label: 'Parties jouées'),
              const SizedBox(width: 12),
              _StatCard(value: '$withWinner', label: 'Avec vainqueur'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(value: '$draws', label: 'Matchs nuls'),
              SizedBox(width: 12),
              _StatCard(
                value: mostPlayed.emoji,
                label: 'Jeu favori\n${mostPlayed.label}',
              ),
            ],
          ),
          SizedBox(height: 24),
          _GameBreakdown(gameCounts: gameCounts),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: context.textColor,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameBreakdown extends StatelessWidget {
  final Map<String, int> gameCounts;

  _GameBreakdown({required this.gameCounts});

  @override
  Widget build(BuildContext context) {
    final sorted = gameCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = gameCounts.values.fold(0, (a, b) => a + b);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Répartition par jeu',
            style: TextStyle(
              color: context.textColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12),
          ...sorted.map((e) {
            final game = GameType.fromId(e.key);
            final pct = total > 0 ? e.value / total : 0.0;
            return Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(game.emoji,
                          style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          game.label,
                          style: TextStyle(
                              color: context.textColor, fontSize: 13),
                        ),
                      ),
                      Text(
                        '${e.value} partie${e.value > 1 ? "s" : ""}',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: context.bgColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Écran verrouillé (utilisateur Free) ──────────────────────────────────────

class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Teaser flou en arrière-plan
        _StatsTeaserBg(),
        // Dégradé assombrissant
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.35, 1.0],
                colors: [
                  context.bgColor.withValues(alpha: 0.2),
                  context.bgColor.withValues(alpha: 0.7),
                  context.bgColor,
                ],
              ),
            ),
          ),
        ),
        // Contenu du cadenas
        Positioned(
          bottom: 40,
          left: 24,
          right: 24,
          child: Column(
            children: [
              Text('🔒', style: TextStyle(fontSize: 52)),
              SizedBox(height: 16),
              Text(
                'Statistiques Pro',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Suivez vos performances, découvrez\nvos jeux favoris et vos meilleures séries.',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.push('/pro'),
                child: const Text('⭐ Passer à Pro'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsTeaserBg extends StatelessWidget {
  const _StatsTeaserBg();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              _TeaserCard(value: '24', label: 'Parties jouées'),
              SizedBox(width: 12),
              _TeaserCard(value: '68%', label: 'Avec vainqueur'),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _TeaserCard(value: '3', label: 'Matchs nuls'),
              SizedBox(width: 12),
              _TeaserCard(value: '🎯', label: 'Jeu favori\nPétanque'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeaserCard extends StatelessWidget {
  final String value;
  final String label;

  const _TeaserCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: context.textColor,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
