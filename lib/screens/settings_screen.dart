import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/pro_provider.dart';
import '../providers/theme_provider.dart';
import '../theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(proProvider).isPro;
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Text(
                'Paramètres',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Bannière Pro
                  if (!isPro)
                    _ProBanner(onTap: () => context.push('/pro'))
                  else
                    const _ProActiveBanner(),
                  const SizedBox(height: 24),

                  // Apparence (Pro)
                  _SettingsSection(
                    title: 'Apparence',
                    items: [
                      _ThemeItem(
                        isPro: isPro,
                        themeMode: themeMode,
                        onToggle: isPro
                            ? (mode) =>
                                ref.read(themeProvider.notifier).setTheme(mode)
                            : null,
                        onLockedTap: () => context.push('/pro'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // À propos
                  _SettingsSection(
                    title: 'À propos',
                    items: [
                      const _SettingsItem(
                        icon: Icons.info_outline_rounded,
                        title: 'Version',
                        trailing: '1.0.0',
                      ),
                      _SettingsDivider(),
                      const _SettingsItem(
                        icon: Icons.person_outline_rounded,
                        title: 'Développé par',
                        trailing: 'VanByte',
                      ),
                    ],
                  ),

                  // Section dev (réinitialiser Pro — visible uniquement si Pro)
                  if (isPro) ...[
                    const SizedBox(height: 24),
                    _SettingsSection(
                      title: 'Développeur',
                      items: [
                        _SettingsItem(
                          icon: Icons.lock_reset_rounded,
                          title: 'Réinitialiser Pro (test)',
                          onTap: () =>
                              ref.read(proProvider.notifier).revoke(),
                          destructive: true,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item thème sombre / clair ─────────────────────────────────────────────────

class _ThemeItem extends StatelessWidget {
  final bool isPro;
  final ThemeMode themeMode;
  final void Function(ThemeMode)? onToggle;
  final VoidCallback onLockedTap;

  const _ThemeItem({
    required this.isPro,
    required this.themeMode,
    required this.onToggle,
    required this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPro) {
      return InkWell(
        onTap: onLockedTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.dark_mode_outlined,
                  color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Thème',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 15)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: AppColors.accent.withOpacity(0.4)),
                ),
                child: const Text(
                  'Pro',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            themeMode == ThemeMode.dark
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            color: AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Thème',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
          ),
          _ThemeToggle(
            isDark: themeMode == ThemeMode.dark,
            onChanged: (isDark) => onToggle?.call(
              isDark ? ThemeMode.dark : ThemeMode.light,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final bool isDark;
  final void Function(bool) onChanged;

  const _ThemeToggle({required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isDark),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              left: isDark ? 0 : 58,
              top: 2,
              child: Container(
                width: 58,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.5), width: 1.5),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'Sombre',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Clair',
                      style: TextStyle(
                        color: !isDark
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bannière Pro ──────────────────────────────────────────────────────────────

class _ProBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _ProBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.25),
              AppColors.accent.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.5)),
        ),
        child: const Row(
          children: [
            Text('⭐', style: TextStyle(fontSize: 28)),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⭐ Passer à Pro',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Déverrouillez toutes les fonctionnalités — 1,99 € / an',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _ProActiveBanner extends StatelessWidget {
  const _ProActiveBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withOpacity(0.4)),
      ),
      child: const Row(
        children: [
          Text('⭐', style: TextStyle(fontSize: 28)),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ScoreTrack Pro — Actif',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Toutes les fonctionnalités déverrouillées',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 22),
        ],
      ),
    );
  }
}

// ─── Composants ────────────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0xFF1A2A47),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    final iconColor =
        destructive ? AppColors.error : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: color, fontSize: 15),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              )
            else if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  color: iconColor, size: 20),
          ],
        ),
      ),
    );
  }
}
