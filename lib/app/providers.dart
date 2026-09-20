import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/vault/data/vault_repository.dart';
import '../features/vault/domain/vault.dart';
import '../features/vault/domain/vault_member.dart';
import '../features/categories/data/category_repository.dart';
import '../features/categories/domain/category.dart';
import '../features/entries/data/entry_repository.dart';
import '../features/entries/domain/entry.dart';
import '../features/activity/data/audit_repository.dart';
import '../features/activity/domain/audit_log.dart';
import '../core/security/secure_storage_service.dart';

// Single repository instances
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
final vaultRepositoryProvider = Provider<VaultRepository>((ref) => VaultRepository());
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) => CategoryRepository());
final entryRepositoryProvider = Provider<EntryRepository>((ref) => EntryRepository());
final auditRepositoryProvider = Provider<AuditRepository>((ref) => AuditRepository());

// Currently authenticated user
final currentUserProvider = StateProvider<AuthUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.currentUser;
});

// Currently active Vault
final activeVaultProvider = StateProvider<Vault?>((ref) => null);

// In-Memory Vault Encryption Key (VEK) - Wiped on app lock or background timeout
final vaultKeyProvider = StateProvider<Uint8List?>((ref) => null);

// Derived state: Vault Unlocked status
final isVaultUnlockedProvider = Provider<bool>((ref) {
  final key = ref.watch(vaultKeyProvider);
  return key != null;
});

// Theme Mode Notifier (System / Light / Dark)
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final mode = await SecureStorageService.getThemeMode();
    if (mode == 'light') {
      state = ThemeMode.light;
    } else if (mode == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    String str = 'system';
    if (mode == ThemeMode.light) str = 'light';
    if (mode == ThemeMode.dark) str = 'dark';
    await SecureStorageService.setThemeMode(str);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// Categories for the active vault
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final vault = ref.watch(activeVaultProvider);
  if (vault == null) return [];
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getCategories(vault.id);
});

// Members for the active vault
final vaultMembersProvider = FutureProvider<List<VaultMember>>((ref) async {
  final vault = ref.watch(activeVaultProvider);
  if (vault == null) return [];
  final repo = ref.watch(vaultRepositoryProvider);
  return repo.getVaultMembers(vault.id);
});

// Entries for a category
final categoryEntriesProvider = FutureProvider.family<List<Entry>, String>((ref, categoryId) async {
  final vek = ref.watch(vaultKeyProvider);
  if (vek == null) return [];
  final repo = ref.watch(entryRepositoryProvider);
  return repo.getEntriesByCategory(categoryId: categoryId, vekBytes: vek);
});

// Audit logs for active vault
final auditLogsProvider = FutureProvider<List<AuditLog>>((ref) async {
  final vault = ref.watch(activeVaultProvider);
  if (vault == null) return [];
  final repo = ref.watch(auditRepositoryProvider);
  return repo.getLogs(vault.id);
});
