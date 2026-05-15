import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/game_type.dart';
import '../models/match_record.dart';
import '../providers/history_provider.dart';
import '../providers/pro_provider.dart';
import '../theme.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);
    final isPro = ref.watch(proProvider).isPro;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historique',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPro
                        ? 'Toutes vos parties'
                        : '5 dernières parties · Passez à Pro pour l\'historique complet',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Bannière limite (free uniquement)
            if (!isPro)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: GestureDetector(
                  onTap: () => context.push('/pro'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Text('🔒', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Limité à 5 parties — ⭐ Passer à Pro pour tout garder',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.accent, size: 18),
                      ],
                    ),
                  ),
                ),
              ),

            // Liste des parties
            Expanded(
              child: historyAsync.when(
                loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => Center(
                  child: Text('Erreur: $err',
                      style: const TextStyle(color: AppColors.error)),
                ),
                data: (matches) {
                  if (matches.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🏆', style: TextStyle(fontSize: 64)),
                          SizedBox(height: 16),
                          Text(
                            'Aucune partie pour l\'instant',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Lancez votre première partie !',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: matches.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (ctx, i) =>
                        _MatchCard(match: matches[i]),
                  );
                },
              ),
            ),

            // Boutons export
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _ExportButtons(isPro: isPro),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Boutons Export ────────────────────────────────────────────────────────────

class _ExportButtons extends StatelessWidget {
  final bool isPro;

  const _ExportButtons({required this.isPro});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ExportButton(
            label: 'Export CSV',
            icon: Icons.table_chart_outlined,
            locked: !isPro,
            onTap: isPro
                ? () => _showExportSnack(context, 'CSV')
                : () => context.push('/pro'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ExportButton(
            label: 'Export JSON',
            icon: Icons.code_rounded,
            locked: !isPro,
            onTap: isPro
                ? () => _showExportSnack(context, 'JSON')
                : () => context.push('/pro'),
          ),
        ),
      ],
    );
  }

  void _showExportSnack(BuildContext context, String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export $format — fonctionnalité à venir !'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool locked;
  final VoidCallback onTap;

  const _ExportButton({
    required this.label,
    required this.icon,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: locked
                ? AppColors.textSecondary.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              locked ? Icons.lock_outline_rounded : icon,
              size: 16,
              color: locked
                  ? AppColors.textSecondary
                  : AppColors.accent,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: locked
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Carte de partie ───────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final MatchRecord match;

  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final game = GameType.fromId(match.gameTypeId);
    final winner = match.winner;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (game.assetImage != null)
                Image.asset(game.assetImage!, width: 32, height: 32)
              else
                Text(game.emoji,
                    style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                game.label,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              const Spacer(),
              Text(
                _formatDate(match.playedAt),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  match.team1Name,
                  style: TextStyle(
                    color: winner == match.team1Name
                        ? AppColors.success
                        : AppColors.textPrimary,
                    fontWeight: winner == match.team1Name
                        ? FontWeight.w800
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${match.score1}  —  ${match.score2}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  match.team2Name,
                  style: TextStyle(
                    color: winner == match.team2Name
                        ? AppColors.success
                        : AppColors.textPrimary,
                    fontWeight: winner == match.team2Name
                        ? FontWeight.w800
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                winner != null ? '🏆 $winner' : '🤝 Match nul',
                style: TextStyle(
                  color: winner != null
                      ? AppColors.success
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
