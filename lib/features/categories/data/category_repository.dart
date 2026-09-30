import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/security/secure_storage_service.dart';
import '../domain/category.dart';

/// Repository for Vault Categories
class CategoryRepository {
  final List<Category> _localCategories = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final stored = await SecureStorageService.getLocalCategories();
      _localCategories.clear();
      _localCategories.addAll(stored.map((c) => Category.fromJson(c)));

      bool migrated = false;
      for (int i = 0; i < _localCategories.length; i++) {
        final oldId = _localCategories[i].id;
        if (!RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(oldId)) {
          final dynamicCatUuid = const Uuid().v4();
          _localCategories[i] = _localCategories[i].copyWith(id: dynamicCatUuid);
          migrated = true;

          try {
            final storedEntries = await SecureStorageService.getLocalEntries();
            bool entryMigrated = false;
            for (int e = 0; e < storedEntries.length; e++) {
              if (storedEntries[e]['category_id'] == oldId) {
                storedEntries[e]['category_id'] = dynamicCatUuid;
                entryMigrated = true;
              }
            }
            if (entryMigrated) {
              await SecureStorageService.saveLocalEntries(storedEntries);
            }
          } catch (_) {}
        }
      }
      if (migrated) {
        await _persist();
      }

      _loaded = true;
    } catch (_) {
      _loaded = true;
    }
  }

  Future<void> _persist() async {
    await SecureStorageService.saveLocalCategories(
      _localCategories.map((c) => c.toJson()).toList(),
    );
  }

  Future<List<Category>> getCategories(String vaultId) async {
    await _ensureLoaded();

    // 1. Calculate entry counts from local phone storage strictly for this vault
    final localEntries = await SecureStorageService.getLocalEntries();
    final Map<String, int> counts = {};
    for (final e in localEntries) {
      final vId = e['vault_id'] as String?;
      if (vId != null && vId.isNotEmpty && vId != vaultId) continue;
      final catId = e['category_id'] as String?;
      if (catId != null) {
        counts[catId] = (counts[catId] ?? 0) + 1;
      }
    }

    // 2. If connected to Supabase, sync categories in background
    if (SupabaseService.isInitialized) {
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('categories')
            .select()
            .eq('vault_id', vaultId)
            .order('position')
            .timeout(const Duration(seconds: 4));

        final remoteCategories = (res as List).map((json) {
          final map = Map<String, dynamic>.from(json);
          return Category.fromJson(map);
        }).toList();

        if (remoteCategories.isNotEmpty) {
          // Merge remote categories into phone storage
          for (final rc in remoteCategories) {
            final idx = _localCategories.indexWhere((c) => c.id == rc.id);
            if (idx != -1) {
              _localCategories[idx] = rc;
            } else {
              _localCategories.add(rc);
            }
          }
          await _persist();
        }
      } catch (_) {
        // Offline or slow network: smoothly use local phone data
      }
    }

    var direct = _localCategories.where((c) => c.vaultId == vaultId).toList();
    if (direct.isEmpty && _localCategories.isNotEmpty) {
      // Pick existing template categories from phone and align to vaultId
      direct = _localCategories.toList();
    }

    // Deduplicate by name (case-insensitive) so cards are never doubled
    final Map<String, Category> uniqueByName = {};
    for (final cat in direct) {
      final key = cat.name.trim().toLowerCase();
      if (!uniqueByName.containsKey(key)) {
        uniqueByName[key] = cat;
      } else {
        // If one of the duplicates has records, prefer that one
        final currentCount = counts[uniqueByName[key]!.id] ?? 0;
        final newCount = counts[cat.id] ?? 0;
        if (newCount > currentCount) {
          uniqueByName[key] = cat;
        }
      }
    }

    final result = uniqueByName.values.toList();
    result.sort((a, b) => a.position.compareTo(b.position));
    return result.map((c) => c.copyWith(recordCount: counts[c.id] ?? 0)).toList();
  }

  Future<Category> createCategory(Category category) async {
    await _ensureLoaded();
    _localCategories.removeWhere((c) => c.id == category.id);
    _localCategories.add(category);
    await _persist();

    if (SupabaseService.isInitialized) {
      try {
        await Supabase.instance.client
            .from('categories')
            .upsert(category.toJson());
      } catch (_) {}
    }
    return category;
  }

  Future<void> updateCategory(Category category) async {
    await _ensureLoaded();
    final idx = _localCategories.indexWhere((c) => c.id == category.id);
    if (idx != -1) {
      _localCategories[idx] = category;
      await _persist();
    }

    if (SupabaseService.isInitialized) {
      try {
        await Supabase.instance.client
            .from('categories')
            .update(category.toJson())
            .eq('id', category.id);
      } catch (_) {}
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    await _ensureLoaded();
    _localCategories.removeWhere((c) => c.id == categoryId);
    await _persist();

    if (SupabaseService.isInitialized) {
      try {
        await Supabase.instance.client
            .from('categories')
            .delete()
            .eq('id', categoryId);
      } catch (_) {}
    }
  }

  /// Seeds standard default categories into the vault with 0 initial records
  Future<void> seedDefaultCategories({
    required String vaultId,
    String? userId,
    List<String>? selectedCategoryNames,
  }) async {
    // If categories were already provisioned, do not duplicate
    final existing = await getCategories(vaultId);
    if (existing.isNotEmpty) return;

    final effectiveUserId = SupabaseService.isInitialized
        ? (Supabase.instance.client.auth.currentUser?.id ?? userId)
        : userId;

    final defaults = [
      Category(
        id: const Uuid().v4(),
        vaultId: vaultId,
        name: 'Investments',
        description: 'Mutual funds • FDs • Stocks',
        icon: 'savings',
        color: '#1D5D5B',
        position: 0,
        isLocked: true, // biometrically protected
        createdBy: effectiveUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recordCount: 0,
      ),
      Category(
        id: const Uuid().v4(),
        vaultId: vaultId,
        name: 'Keys & Places',
        description: 'Physical keys • Lockers • Safe spots',
        icon: 'key',
        color: '#1D5D5B',
        position: 1,
        isLocked: false,
        createdBy: effectiveUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recordCount: 0,
      ),
      Category(
        id: const Uuid().v4(),
        vaultId: vaultId,
        name: 'Insurance',
        description: 'Life • Health • Vehicles',
        icon: 'verified_user',
        color: '#1D5D5B',
        position: 2,
        isLocked: false,
        createdBy: effectiveUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recordCount: 0,
      ),
      Category(
        id: const Uuid().v4(),
        vaultId: vaultId,
        name: 'Cards & Bank',
        description: 'Bank A/c • Debit / Credit cards',
        icon: 'credit_card',
        color: '#565F69',
        position: 3,
        isLocked: true, // sensitive
        createdBy: effectiveUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recordCount: 0,
      ),
      Category(
        id: const Uuid().v4(),
        vaultId: vaultId,
        name: 'Property',
        description: 'Deeds • Flat papers • Land',
        icon: 'home',
        color: '#565F69',
        position: 4,
        isLocked: false,
        createdBy: effectiveUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recordCount: 0,
      ),
      Category(
        id: const Uuid().v4(),
        vaultId: vaultId,
        name: 'Important Docs',
        description: 'Passports • Aadhaar • PAN • Wills',
        icon: 'description',
        color: '#1D5D5B',
        position: 5,
        isLocked: false,
        createdBy: effectiveUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recordCount: 0,
      ),
    ];

    for (final cat in defaults) {
      if (selectedCategoryNames == null || selectedCategoryNames.contains(cat.name)) {
        await createCategory(cat);
      }
    }
  }
}
