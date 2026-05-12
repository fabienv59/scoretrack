import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'games/volleyball/volleyball_screen.dart';
import 'screens/custom_game_screen.dart';
import 'screens/game_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/molkky_game_screen.dart';
import 'screens/pro_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/stats_screen.dart';
import 'widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/stats',
              builder: (context, state) => const StatsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/setup/:gameId',
        builder: (context, state) =>
            SetupScreen(gameId: state.pathParameters['gameId']!),
      ),
      GoRoute(
        path: '/custom',
        builder: (context, state) => const CustomGameScreen(),
      ),
      GoRoute(
        path: '/game',
        builder: (context, state) => const GameScreen(),
      ),
      GoRoute(
        path: '/game/volleyball',
        builder: (context, state) {
          // Les noms d'équipes sont passés en extra depuis SetupScreen
          final extra = state.extra as Map<String, String>? ?? {};
          return VolleyballScreen(
            teamAName: extra['teamA'] ?? 'Équipe A',
            teamBName: extra['teamB'] ?? 'Équipe B',
          );
        },
      ),
      GoRoute(
        path: '/molkky',
        builder: (context, state) => const MolkkyGameScreen(),
      ),
      GoRoute(
        path: '/pro',
        builder: (context, state) => const ProScreen(),
      ),
    ],
  );
});
