import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/category.dart';

/// Repository for Vault Categories management
class CategoryRepository {
  final List<Category> _localCategories = [];

  Future<List<Category>> getCategories(String vaultId) async {
    if (SupabaseService.isInitialized) {
      final client = Supabase.instance.client;
      final res = await client
          .from('categories')
          .select('*, entries(count)')
          .eq('vault_id', vaultId)
          .order('position');

      return (res as List).map((json) {
        final entriesAgg = json['entries'] as List?;
        int count = 0;
        if (entriesAgg != null && entriesAgg.isNotEmpty) {
          count = entriesAgg.first['count'] as int? ?? 0;
        }
        final map = Map<String, dynamic>.from(json);
        map['record_count'] = count;
        return Category.fromJson(map);
      }).toList();
    } else {
      return List.unmodifiable(_localCategories.where((c) => c.vaultId == vaultId));
    }
  }

  Future<Category> createCategory(Category category) async {
    if (SupabaseService.isInitialized) {
      final res = await Supabase.instance.client
          .from('categories')
          .insert(category.toJson())
          .select()
          .single();
      return Category.fromJson(res);
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
    final defaults = [
      Category(
        id: 'cat-investments-$vaultId',
        vaultId: vaultId,
        name: 'Investments',
        description: 'Mutual funds • FDs • Stocks',
        icon: 'savings',
        color: '#1D5D5B',
        position: 0,
        isLocked: true, // biometrically protected
        createdBy: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recordCount: 8,
      ),
      Category(
        id: 'cat-keys-$vaultId',
        vaultId: vaultId,
        name: 'Keys & Places',
        description: 'Physical keys • Lockers • Safe spots',
        icon: 'key',
        color: '#1D5D5B',
        position: 1,
        isLocked: false,
        createdBy: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recordCount: 14,
      ),
      Category(
        id: 'cat-insurance-$vaultId',
        vaultId: vaultId,
        name: 'Insurance',
        description: 'Life • Health • Vehicles',
        icon: 'verified_user',
        color: '#1D5D5B',
        position: 2,
        isLocked: false,
        createdBy: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recordCount: 5,
      ),
      Category(
        id: 'cat-cards-$vaultId',
        vaultId: vaultId,
        name: 'Cards & Bank',
        description: 'Bank A/c • Debit / Credit cards',
        icon: 'credit_card',
        color: '#565F69',
        position: 3,
        isLocked: true, // sensitive
        createdBy: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recordCount: 4,
      ),
      Category(
        id: 'cat-property-$vaultId',
        vaultId: vaultId,
        name: 'Property',
        description: 'Deeds • Flat papers • Land',
        icon: 'home',
        color: '#565F69',
        position: 4,
        isLocked: false,
        createdBy: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recordCount: 3,
      ),
      Category(
        id: 'cat-docs-$vaultId',
        vaultId: vaultId,
        name: 'Important Docs',
        description: 'Passports • Aadhaar • PAN • Wills',
        icon: 'description',
        color: '#1D5D5B',
        position: 5,
        isLocked: false,
        createdBy: userId,
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
