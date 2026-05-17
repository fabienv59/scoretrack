import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/game_type.dart';
import '../models/match_record.dart';
import '../providers/history_provider.dart';
import '../providers/pro_provider.dart';
import '../services/database_service.dart';
import '../theme.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _busy = false;

  // ─── Export CSV ──────────────────────────────────────────────────────────────

  Future<void> _exportCsv() async {
    if (!ref.read(proProvider).isPro) {
      context.push('/pro');
      return;
    }
    setState(() => _busy = true);
    try {
      final matches = await DatabaseService.instance.getAllMatches();
      final rows = <List<dynamic>>[
        ['Date', 'Jeu', 'Équipe1', 'Score1', 'Équipe2', 'Score2', 'Vainqueur'],
        ...matches.map((m) => [
              _formatIso(m.playedAt),
              GameType.fromId(m.gameTypeId).label,
              m.team1Name,
              m.score1,
              m.team2Name,
              m.score2,
              m.winner ?? 'Match nul',
            ]),
      ];
      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/scoretrack_export.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Historique ScoreTrack',
      );
    } catch (e) {
      if (mounted) _showError('Erreur export CSV : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─── Export JSON ─────────────────────────────────────────────────────────────

  Future<void> _exportJson() async {
    if (!ref.read(proProvider).isPro) {
      context.push('/pro');
      return;
    }
    setState(() => _busy = true);
    try {
      final matches = await DatabaseService.instance.getAllMatches();
      final data = matches.map((m) => m.toMap()).toList();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/scoretrack_export.json');
      await file.writeAsString(json);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Historique ScoreTrack',
      );
    } catch (e) {
      if (mounted) _showError('Erreur export JSON : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─── Import JSON ─────────────────────────────────────────────────────────────

  Future<void> _importJson() async {
    if (!ref.read(proProvider).isPro) {
      context.push('/pro');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _busy = true);
    try {
      final content = await File(result.files.single.path!).readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      int count = 0;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final r = MatchRecord.fromMap(map);
        // Strip id → DB autoincrement, ignore duplicates via importMatch
        final inserted = await DatabaseService.instance.importMatch(
          MatchRecord(
            gameTypeId: r.gameTypeId,
            team1Name: r.team1Name,
            team2Name: r.team2Name,
            score1: r.score1,
            score2: r.score2,
            playedAt: r.playedAt,
            winnerName: r.winnerName,
          ),
        );
        if (inserted > 0) count++;
      }
      ref.invalidate(historyProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '$count partie${count > 1 ? "s" : ""} importée${count > 1 ? "s" : ""} avec succès'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) _showError('Erreur import : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  String _formatIso(DateTime dt) =>
      dt.toIso8601String().substring(0, 16).replaceFirst('T', ' ');

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyProvider);
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
                  Text(
                    'Historique',
                    style: TextStyle(
                        color: context.textColor,
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

            Expanded(
              child: historyAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
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
                                color: AppColors.textSecondary, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Lancez votre première partie !',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _MatchCard(match: matches[i]),
                  );
                },
              ),
            ),

            // Boutons export / import
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _busy
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: 'Export CSV',
                                icon: Icons.table_chart_outlined,
                                locked: !isPro,
                                onTap: _exportCsv,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionButton(
                                label: 'Export JSON',
                                icon: Icons.code_rounded,
                                locked: !isPro,
                                onTap: _exportJson,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _ActionButton(
                          label: 'Importer des données',
                          icon: Icons.upload_file_rounded,
                          locked: !isPro,
                          onTap: _importJson,
                          fullWidth: true,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bouton action (export / import) ─────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool locked;
  final VoidCallback onTap;
  final bool fullWidth;

  _ActionButton({
    required this.label,
    required this.icon,
    required this.locked,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: context.surfaceColor,
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
              color: locked ? AppColors.textSecondary : AppColors.accent,
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: locked ? AppColors.textSecondary : context.textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
    return child;
  }
}

// ─── Carte de partie ──────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final MatchRecord match;

  _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final game = GameType.fromId(match.gameTypeId);
    final winner = match.winner;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
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
                Text(game.emoji, style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                game.label,
                style: TextStyle(
                    color: context.textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              Spacer(),
              Text(
                _formatDate(match.playedAt),
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  match.team1Name,
                  style: TextStyle(
                    color: winner == match.team1Name
                        ? AppColors.success
                        : context.textColor,
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
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: context.bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${match.score1}  —  ${match.score2}',
                  style: TextStyle(
                    color: context.textColor,
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
                        : context.textColor,
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
