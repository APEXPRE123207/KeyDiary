import 'package:go_router/go_router.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/lock_screen.dart';
import '../features/vault/presentation/security_setup_screen.dart';
import '../features/categories/presentation/category_setup_screen.dart';
import '../features/categories/presentation/home_screen.dart';
import '../features/categories/presentation/category_detail_screen.dart';
import '../features/categories/domain/category.dart';
import '../features/entries/presentation/entry_detail_screen.dart';
import '../features/entries/presentation/entry_editor_screen.dart';
import '../features/entries/domain/entry.dart';
import '../features/vault/presentation/family_vault_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/activity/presentation/activity_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/lock',
      builder: (context, state) => const LockScreen(),
    ),
    GoRoute(
      path: '/security-setup',
      builder: (context, state) => const SecuritySetupScreen(),
    ),
    GoRoute(
      path: '/category-setup',
      builder: (context, state) => const CategorySetupScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/category/:id',
      builder: (context, state) {
        final categoryId = state.pathParameters['id']!;
        final category = state.extra as Category?;
        return CategoryDetailScreen(categoryId: categoryId, category: category);
      },
    ),
    GoRoute(
      path: '/entry/:id',
      builder: (context, state) {
        final entryId = state.pathParameters['id']!;
        final entry = state.extra as Entry?;
        return EntryDetailScreen(entryId: entryId, entry: entry);
      },
    ),
    GoRoute(
      path: '/entry-editor',
      builder: (context, state) {
        final categoryId = state.uri.queryParameters['categoryId'] ?? 'cat-default';
        final entry = state.extra as Entry?;
        return EntryEditorScreen(categoryId: categoryId, entry: entry);
      },
    ),
    GoRoute(
      path: '/family-vault',
      builder: (context, state) => const FamilyVaultScreen(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/activity',
      builder: (context, state) => const ActivityScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
