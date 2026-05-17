import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pro_provider.dart';
import '../theme.dart';

class ProScreen extends ConsumerWidget {
  const ProScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proState = ref.watch(proProvider);
    final isPro = proState.isPro;
    final isLoading = proState.isLoading;

    // Afficher les erreurs IAP via SnackBar
    ref.listen<ProState>(proProvider, (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      }
      if (!prev!.isPro && next.isPro) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bienvenue dans ScoreTrack Pro ! 🎉'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(title: const Text('ScoreTrack Pro')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.3),
                    AppColors.accent.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Text('⭐', style: TextStyle(fontSize: 56)),
                  SizedBox(height: 12),
                  Text(
                    'ScoreTrack Pro',
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPro ? '✓ Abonnement actif' : '1,99 € / an',
                    style: TextStyle(
                      color: isPro ? AppColors.success : AppColors.accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Liste des fonctionnalités
            const _FeatureRow(
              icon: '📜',
              title: 'Historique illimité',
              subtitle: 'Conservez toutes vos parties sans limite',
            ),
            const _FeatureRow(
              icon: '📊',
              title: 'Statistiques avancées',
              subtitle: 'Suivez vos performances et découvrez vos jeux favoris',
            ),
            const _FeatureRow(
              icon: '📤',
              title: 'Export CSV / JSON',
              subtitle: 'Exportez et partagez votre historique de parties',
            ),
            const _FeatureRow(
              icon: '📥',
              title: 'Import de données',
              subtitle: 'Restaurez votre historique depuis un fichier',
            ),
            const _FeatureRow(
              icon: '🎨',
              title: 'Thème sombre / clair',
              subtitle: 'Personnalisez l\'apparence de l\'application',
            ),
            const _FeatureRow(
              icon: '🚫',
              title: 'Sans publicité',
              subtitle: 'Une expérience épurée et sans interruption',
            ),

            const SizedBox(height: 40),

            if (isPro) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Vous êtes membre Pro',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else ...[
                ElevatedButton(
                  onPressed: () =>
                      ref.read(proProvider.notifier).purchasePro(),
                  child: const Text('Acheter — 1,99 € / an'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () =>
                        ref.read(proProvider.notifier).restorePurchases(),
                    child: const Text(
                      'Restaurer l\'achat',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(icon, style: TextStyle(fontSize: 22)),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.success, size: 20),
        ],
      ),
    );
  }
}
