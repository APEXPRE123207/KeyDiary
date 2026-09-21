import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/category.dart';

/// Repository for Vault Categories
class CategoryRepository {
  final List<Category> _localCategories = [];

  Future<List<Category>> getCategories(String vaultId) async {
    if (SupabaseService.isInitialized) {
      final res = await Supabase.instance.client
          .from('categories')
          .select()
          .eq('vault_id', vaultId)
          .order('position');

      return (res as List).map((json) => Category.fromJson(json)).toList();
    } else {
      return _localCategories.where((c) => c.vaultId == vaultId).toList();
    }
  }

  Future<Category> createCategory(Category category) async {
    if (SupabaseService.isInitialized) {
      await Supabase.instance.client
          .from('categories')
          .insert(category.toJson());
      return category;
    } else {
      _localCategories.add(category);
      return category;
    }
  }

  Future<void> updateCategory(Category category) async {
    if (SupabaseService.isInitialized) {
      await Supabase.instance.client
          .from('categories')
          .update(category.toJson())
          .eq('id', category.id);
    } else {
      final idx = _localCategories.indexWhere((c) => c.id == category.id);
      if (idx != -1) {
        _localCategories[idx] = category;
      }
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    if (SupabaseService.isInitialized) {
      await Supabase.instance.client
          .from('categories')
          .delete()
          .eq('id', categoryId);
    } else {
      _localCategories.removeWhere((c) => c.id == categoryId);
    }
  }

  /// Seeds standard default categories into the vault
  Future<void> seedDefaultCategories({
    required String vaultId,
    String? userId,
    List<String>? selectedCategoryNames,
  }) async {
    if (SupabaseService.isInitialized) {
      // If categories were already provisioned (e.g. by database seed trigger), do not duplicate
      final existing = await getCategories(vaultId);
      if (existing.isNotEmpty) return;
    }

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
        recordCount: 8,
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
        recordCount: 14,
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
        recordCount: 5,
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
        recordCount: 4,
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
        recordCount: 3,
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
        recordCount: 12,
      ),
    ];

    for (final cat in defaults) {
      if (selectedCategoryNames == null || selectedCategoryNames.contains(cat.name)) {
        await createCategory(cat);
      }
    }
  }
}
