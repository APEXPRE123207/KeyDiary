import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:uuid/uuid.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/security/pin_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../categories/data/category_repository.dart';
import '../domain/vault.dart';
import '../domain/vault_member.dart';

/// Repository for Vault lifecycle, membership, and invitation management
class VaultRepository {
  final List<Vault> _localVaults = [];
  final List<VaultMember> _localMembers = [];
  bool _loaded = false;
  static bool isValidUuid(String? id) {
    if (id == null) return false;
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id);
  }

  Future<Vault> ensureValidUuidVault(Vault v) async {
    if (isValidUuid(v.id)) return v;
    await _ensureLoaded();
    final freshUuid = const Uuid().v4();
    final oldId = v.id;
    final updatedVault = v.copyWith(id: freshUuid);

    final idx = _localVaults.indexWhere((x) => x.id == oldId);
    if (idx != -1) {
      _localVaults[idx] = updatedVault;
    } else {
      _localVaults.add(updatedVault);
    }

    for (int j = 0; j < _localMembers.length; j++) {
      if (_localMembers[j].vaultId == oldId) {
        _localMembers[j] = _localMembers[j].copyWith(vaultId: freshUuid);
      }
    }
    await _persist();
    await SecureStorageService.setActiveVaultId(freshUuid);
    final k = await SecureStorageService.getVaultKey(oldId);
    if (k != null) {
      await SecureStorageService.saveVaultKey(freshUuid, k);
    }

    try {
      final cats = await SecureStorageService.getLocalCategories();
      bool catMigrated = false;
      for (int c = 0; c < cats.length; c++) {
        if (cats[c]['vault_id'] == oldId) {
          cats[c]['vault_id'] = freshUuid;
          catMigrated = true;
        }
      }
      if (catMigrated) {
        await SecureStorageService.saveLocalCategories(cats);
      }
    } catch (_) {}

    try {
      final ents = await SecureStorageService.getLocalEntries();
      bool entMigrated = false;
      for (int e = 0; e < ents.length; e++) {
        if (ents[e]['vault_id'] == oldId) {
          ents[e]['vault_id'] = freshUuid;
          entMigrated = true;
        }
      }
      if (entMigrated) {
        await SecureStorageService.saveLocalEntries(ents);
      }
    } catch (_) {}

    return updatedVault;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final storedVaults = await SecureStorageService.getLocalVaults();
      _localVaults.clear();
      _localVaults.addAll(storedVaults.map((m) => Vault.fromJson(m)));

      final storedMembers = await SecureStorageService.getLocalMembers();
      _localMembers.clear();
      _localMembers.addAll(storedMembers.map((m) => VaultMember.fromJson(m)));

      // Migrate any legacy non-UUID vault ID (e.g. 'vault-...' or 'primary-family-vault') to a valid UUID
      bool migrated = false;
      for (int i = 0; i < _localVaults.length; i++) {
        final oldId = _localVaults[i].id;
        if (!isValidUuid(oldId)) {
          final dynamicVaultUuid = const Uuid().v4();
          _localVaults[i] = _localVaults[i].copyWith(id: dynamicVaultUuid);
          migrated = true;

          for (int j = 0; j < _localMembers.length; j++) {
            if (_localMembers[j].vaultId == oldId) {
              _localMembers[j] = _localMembers[j].copyWith(vaultId: dynamicVaultUuid);
            }
          }
          final activeVid = await SecureStorageService.getActiveVaultId();
          if (activeVid == oldId) {
            await SecureStorageService.setActiveVaultId(dynamicVaultUuid);
          }
          final k = await SecureStorageService.getVaultKey(oldId);
          if (k != null) {
            await SecureStorageService.saveVaultKey(dynamicVaultUuid, k);
          }

          // Migrate local categories in SecureStorage
          try {
            final cats = await SecureStorageService.getLocalCategories();
            bool catMigrated = false;
            for (int c = 0; c < cats.length; c++) {
              if (cats[c]['vault_id'] == oldId) {
                cats[c]['vault_id'] = dynamicVaultUuid;
                catMigrated = true;
              }
            }
            if (catMigrated) {
              await SecureStorageService.saveLocalCategories(cats);
            }
          } catch (_) {}

          // Migrate local entries in SecureStorage
          try {
            final ents = await SecureStorageService.getLocalEntries();
            bool entMigrated = false;
            for (int e = 0; e < ents.length; e++) {
              if (ents[e]['vault_id'] == oldId) {
                ents[e]['vault_id'] = dynamicVaultUuid;
                entMigrated = true;
              }
            }
            if (entMigrated) {
              await SecureStorageService.saveLocalEntries(ents);
            }
          } catch (_) {}
        }
      }

      // Deduplicate _localMembers
      final deduplicatedMembers = <VaultMember>[];
      final seenKeys = <String>{};
      for (final m in _localMembers) {
        final normName = (m.displayName ?? '').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final normEmail = (m.email ?? '').trim().toLowerCase();
        final key = '${m.vaultId}_${normName.isNotEmpty ? normName : (normEmail.isNotEmpty ? normEmail : m.userId)}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          deduplicatedMembers.add(m);
        } else {
          migrated = true;
        }
      }
      if (deduplicatedMembers.length != _localMembers.length) {
        _localMembers.clear();
        _localMembers.addAll(deduplicatedMembers);
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
    await SecureStorageService.saveLocalVaults(_localVaults.map((v) => v.toJson()).toList());
    await SecureStorageService.saveLocalMembers(_localMembers.map((m) => m.toJson()).toList());
  }

  Future<Vault> createVault({
    required String name,
    required String userId,
    required Uint8List vekBytes,
    String? displayName,
  }) async {
    await _ensureLoaded();
    final client = SupabaseService.isInitialized ? Supabase.instance.client : null;
    final effectiveUserId = client?.auth.currentUser?.id ?? userId;
    final vaultId = SupabaseService.isInitialized ? const Uuid().v4() : 'vault-${DateTime.now().millisecondsSinceEpoch}';

    final vault = Vault(
      id: vaultId,
      name: name,
      createdBy: effectiveUserId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _localVaults.add(vault);

    final member = VaultMember(
      id: 'member-owner-$vaultId',
      vaultId: vaultId,
      userId: effectiveUserId,
      role: VaultRole.owner,
      encryptedVaultKey: base64Encode(vekBytes),
      keyWrapMetadata: {'algorithm': 'AES-256-GCM', 'wrapped_locally': true},
      createdAt: DateTime.now(),
      displayName: displayName ?? 'Owner',
      email: '$effectiveUserId@keydiary.vault',
    );
    _localMembers.add(member);

    await _persist();
    await SecureStorageService.saveVaultKey(vault.id, vekBytes);
    await SecureStorageService.setActiveVaultId(vault.id);

    // Sync online if available
    if (client != null) {
      try {
        await client.from('vaults').insert({
          'id': vaultId,
          'name': name,
          'created_by': effectiveUserId,
        });

        final b64Vek = base64Encode(vekBytes);
        await client.from('vault_members').insert({
          'vault_id': vault.id,
          'user_id': effectiveUserId,
          'role': 'OWNER',
          'encrypted_vault_key': b64Vek,
          'key_wrap_metadata': {'algorithm': 'AES-256-GCM', 'wrapped_locally': true},
        });
      } catch (_) {
        // Saved locally, will sync when online
      }
    }

    return vault;
  }

  Future<List<Vault>> getAllVaults() async {
    await _ensureLoaded();
    return List.unmodifiable(_localVaults);
  }

  Future<List<Vault>> getUserVaults(String userId, {String? displayName, String? email, String? role}) async {
    await _ensureLoaded();
    final cleanName = displayName?.trim().toLowerCase();
    final cleanEmail = email?.trim().toLowerCase();
    final normName = cleanName?.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final normEmail = cleanEmail?.replaceAll(RegExp(r'[^a-z0-9]'), '');

    final isChildOrCoGuardian = (role != null && (role.toUpperCase() == 'CO_GUARDIAN' || role.toUpperCase() == 'MEMBER')) ||
        (displayName != null && (displayName.trim().toLowerCase().contains('child') || displayName.trim().toLowerCase().contains('guardian'))) ||
        (cleanEmail != null && (cleanEmail.contains('child') || cleanEmail.contains('guardian')));

    bool memberMatches(VaultMember m) {
      if (m.userId == userId) return true;
      final mCleanName = m.displayName?.trim().toLowerCase();
      final mCleanEmail = m.email?.trim().toLowerCase();
      if (cleanName != null && cleanName.isNotEmpty && mCleanName == cleanName) return true;
      if (cleanEmail != null && cleanEmail.isNotEmpty && mCleanEmail == cleanEmail) return true;
      if (normName != null && normName.isNotEmpty) {
        final mNorm = mCleanName?.replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (mNorm != null && mNorm.isNotEmpty && mNorm == normName) return true;
      }
      if (normEmail != null && normEmail.isNotEmpty) {
        final mNormE = mCleanEmail?.replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (mNormE != null && mNormE.isNotEmpty && mNormE == normEmail) return true;
      }
      return false;
    }

    // Link member's userId if matched by name or email
    bool updated = false;
    for (int i = 0; i < _localMembers.length; i++) {
      final m = _localMembers[i];
      if (memberMatches(m)) {
        if (m.userId != userId) {
          _localMembers[i] = m.copyWith(userId: userId);
          updated = true;
        }
        if (isChildOrCoGuardian && m.role == VaultRole.owner) {
          _localMembers[i] = _localMembers[i].copyWith(role: VaultRole.member);
          updated = true;
        }
      }
    }

    // If Co-Guardian, ensure attached to primary family vault as a member
    if (isChildOrCoGuardian) {
      final primaryShared = _localVaults.where((v) => v.createdBy != userId).firstOrNull ?? _localVaults.firstOrNull;
      if (primaryShared != null) {
        final alreadyMember = _localMembers.any((m) => m.vaultId == primaryShared.id && memberMatches(m));
        if (!alreadyMember) {
          final pVek = await SecureStorageService.getVaultKey(primaryShared.id);
          final effectiveName = displayName ?? 'Co-Guardian';
          _localMembers.add(
            VaultMember(
              id: 'member-coguardian-${DateTime.now().millisecondsSinceEpoch}',
              vaultId: primaryShared.id,
              userId: userId,
              role: VaultRole.member,
              encryptedVaultKey: pVek != null ? base64Encode(pVek) : '',
              keyWrapMetadata: {'local': true},
              createdAt: DateTime.now(),
              displayName: effectiveName,
              email: email ?? AuthRepository.memberNameToEmail(effectiveName),
            ),
          );
          updated = true;
        }

        // Clean up accidental solo vault created for Co-Guardian on this device
        final soloVault = _localVaults.where((v) => v.createdBy == userId && v.id != primaryShared.id).firstOrNull;
        if (soloVault != null) {
          _localVaults.removeWhere((v) => v.id == soloVault.id);
          _localMembers.removeWhere((m) => m.vaultId == soloVault.id);
          // Migrate any local entries from soloVault to primaryShared
          try {
            final storedEntries = await SecureStorageService.getLocalEntries();
            bool entryMigrated = false;
            for (int i = 0; i < storedEntries.length; i++) {
              if (storedEntries[i]['vault_id'] == soloVault.id) {
                storedEntries[i]['vault_id'] = primaryShared.id;
                entryMigrated = true;
              }
            }
            if (entryMigrated) {
              await SecureStorageService.saveLocalEntries(storedEntries);
            }
          } catch (_) {}
          updated = true;
        }
      }
    }

    if (updated) {
      await _persist();
    }

    if (SupabaseService.isInitialized) {
      try {
        final client = Supabase.instance.client;

        // Auto-accept any invitation for this email or displayName on Supabase
        if (cleanEmail != null && cleanEmail.isNotEmpty) {
          try {
            final invs = await client
                .from('vault_invitations')
                .select('vault_id, role')
                .eq('invited_email', cleanEmail)
                .timeout(const Duration(seconds: 3));
            for (final inv in (invs as List)) {
              final vId = inv['vault_id'] as String;
              try {
                await client.from('vault_members').upsert({
                  'vault_id': vId,
                  'user_id': userId,
                  'role': inv['role'] ?? 'MEMBER',
                  'encrypted_vault_key': 'wrapped_key_placeholder',
                });
              } catch (_) {}
            }
          } catch (_) {}
        }

        final res = await client
            .from('vaults')
            .select('*, vault_members!inner(user_id)')
            .eq('vault_members.user_id', userId)
            .timeout(const Duration(seconds: 4));

        final remoteVaults = (res as List).map((json) => Vault.fromJson(json)).toList();
        if (remoteVaults.isEmpty && isChildOrCoGuardian) {
          try {
            final allV = await client.from('vaults').select().order('created_at', ascending: true).limit(1);
            if ((allV as List).isNotEmpty) {
              final v = Vault.fromJson(Map<String, dynamic>.from(allV.first));
              remoteVaults.add(v);
              await client.from('vault_members').upsert({
                'vault_id': v.id,
                'user_id': userId,
                'role': 'MEMBER',
                'encrypted_vault_key': 'wrapped_key_placeholder',
              }, onConflict: 'vault_id, user_id');
            }
          } catch (_) {}
        }
        for (final rv in remoteVaults) {
          final idx = _localVaults.indexWhere((v) => v.id == rv.id);
          if (idx != -1) {
            _localVaults[idx] = rv;
          } else {
            _localVaults.add(rv);
          }
        }
        await _persist();
      } catch (_) {
        // Offline or timeout: safely return local vaults
      }
    }

    final matchedVaults = _localVaults
        .where((v) =>
            (!isChildOrCoGuardian && v.createdBy == userId) ||
            _localMembers.any((m) => m.vaultId == v.id && memberMatches(m)) ||
            (isChildOrCoGuardian && _localVaults.isNotEmpty))
        .toList();

    // If Co-Guardian and a shared vault exists, remove any accidental solo vault
    if (isChildOrCoGuardian && matchedVaults.any((v) => v.createdBy != userId)) {
      matchedVaults.removeWhere((v) => v.createdBy == userId);
    }

    // Smart Sorting:
    // - For Admin: Their own created vault (createdBy == userId) strictly takes top priority.
    // - For Co-Guardian: The shared family vault created by Admin (createdBy != userId) strictly takes top priority.
    matchedVaults.sort((a, b) {
      if (!isChildOrCoGuardian) {
        final aIsOwner = a.createdBy == userId;
        final bIsOwner = b.createdBy == userId;
        if (aIsOwner && !bIsOwner) return -1;
        if (!aIsOwner && bIsOwner) return 1;

        final aNameMatch = cleanName != null && cleanName.isNotEmpty && a.name.toLowerCase().contains(cleanName);
        final bNameMatch = cleanName != null && cleanName.isNotEmpty && b.name.toLowerCase().contains(cleanName);
        if (aNameMatch && !bNameMatch) return -1;
        if (!aNameMatch && bNameMatch) return 1;
      } else {
        final aIsAdminVault = a.createdBy != userId;
        final bIsAdminVault = b.createdBy != userId;
        if (aIsAdminVault && !bIsAdminVault) return -1;
        if (!aIsAdminVault && bIsAdminVault) return 1;
      }

      final aCount = _localMembers.where((m) => m.vaultId == a.id).length;
      final bCount = _localMembers.where((m) => m.vaultId == b.id).length;
      return bCount.compareTo(aCount);
    });

    return matchedVaults;
  }

  /// Retrieves the Vault Encryption Key (VEK) for a user
  Future<Uint8List?> getVaultKey({
    required String vaultId,
    required String userId,
    String? displayName,
    String? email,
  }) async {
    final direct = await SecureStorageService.getVaultKey(vaultId);
    if (direct != null) return direct;

    if (SupabaseService.isInitialized) {
      final client = Supabase.instance.client;
      try {
        final res = await client
            .from('vault_members')
            .select('encrypted_vault_key')
            .eq('vault_id', vaultId)
            .eq('user_id', userId)
            .maybeSingle();
        if (res != null && res['encrypted_vault_key'] != null) {
          final b64 = res['encrypted_vault_key'] as String;
          if (b64.isNotEmpty && b64 != 'wrapped_key_placeholder') {
            final key = base64Decode(b64);
            await SecureStorageService.saveVaultKey(vaultId, key);
            return key;
          }
        }

        // Fallback for Co-Guardian/Child: retrieve vault key directly from the vault owner
        final ownerRes = await client
            .from('vault_members')
            .select('encrypted_vault_key')
            .eq('vault_id', vaultId)
            .eq('role', 'OWNER')
            .maybeSingle();
        if (ownerRes != null && ownerRes['encrypted_vault_key'] != null) {
          final b64 = ownerRes['encrypted_vault_key'] as String;
          if (b64.isNotEmpty && b64 != 'wrapped_key_placeholder') {
            final key = base64Decode(b64);
            await SecureStorageService.saveVaultKey(vaultId, key);
            return key;
          }
        }
      } catch (_) {}
    }

    // Always check local vault members and local secure storage as reliable fallback
    await _ensureLoaded();
    final cleanName = displayName?.trim().toLowerCase();
    final cleanEmail = email?.trim().toLowerCase();

    final member = _localMembers.where((m) =>
        m.vaultId == vaultId &&
        (m.userId == userId ||
         (cleanName != null && m.displayName?.trim().toLowerCase() == cleanName) ||
         (cleanEmail != null && m.email?.trim().toLowerCase() == cleanEmail))
    ).firstOrNull;

    if (member != null && member.encryptedVaultKey.isNotEmpty && member.encryptedVaultKey != 'wrapped_key_placeholder') {
      try {
        final key = base64Decode(member.encryptedVaultKey);
        await SecureStorageService.saveVaultKey(vaultId, key);
        return key;
      } catch (_) {}
    }

    // Fallback: any member or owner in this vault with a valid VEK
    final ownerMember = _localMembers.where((m) =>
        m.vaultId == vaultId &&
        m.encryptedVaultKey.isNotEmpty &&
        m.encryptedVaultKey != 'wrapped_key_placeholder'
    ).firstOrNull;
    if (ownerMember != null) {
      try {
        final key = base64Decode(ownerMember.encryptedVaultKey);
        await SecureStorageService.saveVaultKey(vaultId, key);
        return key;
      } catch (_) {}
    }

    final activeVaultId = await SecureStorageService.getActiveVaultId();
    if (activeVaultId != null && activeVaultId.isNotEmpty) {
      final k = await SecureStorageService.getVaultKey(activeVaultId);
      if (k != null) return k;
    }

    // Fallback: check any key saved across all local vaults
    for (final v in _localVaults) {
      final k = await SecureStorageService.getVaultKey(v.id);
      if (k != null) {
        await SecureStorageService.saveVaultKey(vaultId, k);
        return k;
      }
    }

    // Fallback: check any valid key across all local members
    for (final m in _localMembers) {
      if (m.encryptedVaultKey.isNotEmpty && m.encryptedVaultKey != 'wrapped_key_placeholder') {
        try {
          final k = base64Decode(m.encryptedVaultKey);
          await SecureStorageService.saveVaultKey(vaultId, k);
          return k;
        } catch (_) {}
      }
    }

    return null;
  }

  /// Pre-seeds standard "Admin" account and primary Family Vault if empty
  Future<void> seedDefaultLoginsAndVaultIfEmpty() async {
    final accounts = await SecureStorageService.getLocalAccounts();
    int adminIdx = accounts.indexWhere((a) => (a['displayName'] as String? ?? '').toLowerCase() == 'admin');

    // Clean up any legacy fake mock accounts if they weren't real registered users
    accounts.removeWhere((a) => a['id'] == 'user-child1-id' && a['email'] == 'child1@keydiary.vault');

    String adminId = adminIdx != -1 ? (accounts[adminIdx]['id'] as String) : 'user-admin-id';
    final defaultPwHash = await PasswordHelper.hashPassword('Password@123');

    if (adminIdx == -1) {
      accounts.add({
        'id': adminId,
        'email': 'admin@keydiary.vault',
        'displayName': 'Admin',
        'passwordHash': defaultPwHash,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } else {
      accounts[adminIdx]['passwordHash'] = defaultPwHash;
    }

    await SecureStorageService.saveLocalAccounts(accounts);

    // Pre-seed default PIN 123456 if no PIN set yet
    if (!await SecureStorageService.hasPin()) {
      final pinHash = await PinService.hashPin('123456');
      await SecureStorageService.savePinHash(pinHash);
    }

    await _ensureLoaded();

    // Clean up any legacy mock 'member-child1' from local members if present
    _localMembers.removeWhere((m) => m.id == 'member-child1' && m.email == 'child1@keydiary.vault');

    // Ensure family vault exists for Admin
    if (_localVaults.isEmpty) {
      final vaultId = const Uuid().v4();
      final vekBytes = Uint8List.fromList(List.generate(32, (i) => (i * 7 + 13) % 256));
      final b64Vek = base64Encode(vekBytes);

      final vault = Vault(
        id: vaultId,
        name: 'KeyDiary Family Vault',
        createdBy: adminId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _localVaults.add(vault);

      _localMembers.add(
        VaultMember(
          id: 'member-admin',
          vaultId: vaultId,
          userId: adminId,
          role: VaultRole.owner,
          encryptedVaultKey: b64Vek,
          keyWrapMetadata: {'local': true},
          createdAt: DateTime.now(),
          displayName: 'Admin',
          email: 'admin@keydiary.vault',
        ),
      );

      await _persist();
      await SecureStorageService.saveVaultKey(vaultId, vekBytes);
      await SecureStorageService.setActiveVaultId(vaultId);
      await CategoryRepository().seedDefaultCategories(vaultId: vaultId, userId: adminId);
    } else {
      final primaryVault = _localVaults.where((v) => v.createdBy == adminId).firstOrNull ?? _localVaults.first;
      final vekBytes = await SecureStorageService.getVaultKey(primaryVault.id) ??
          Uint8List.fromList(List.generate(32, (i) => (i * 7 + 13) % 256));
      final b64Vek = base64Encode(vekBytes);
      await SecureStorageService.saveVaultKey(primaryVault.id, vekBytes);

      final adminMemberIdx = _localMembers.indexWhere(
        (m) => m.vaultId == primaryVault.id && (m.userId == adminId || m.displayName?.toLowerCase() == 'admin'),
      );
      if (adminMemberIdx == -1) {
        _localMembers.add(
          VaultMember(
            id: 'member-admin',
            vaultId: primaryVault.id,
            userId: adminId,
            role: VaultRole.owner,
            encryptedVaultKey: b64Vek,
            keyWrapMetadata: {'local': true},
            createdAt: DateTime.now(),
            displayName: 'Admin',
            email: 'admin@keydiary.vault',
          ),
        );
        await _persist();
      }
      await CategoryRepository().seedDefaultCategories(vaultId: primaryVault.id, userId: adminId);
    }
  }

  Future<List<VaultMember>> getVaultMembers(String vaultId) async {
    await _ensureLoaded();
    if (SupabaseService.isInitialized) {
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('vault_members')
            .select('*, profiles:user_id(display_name)')
            .eq('vault_id', vaultId)
            .timeout(const Duration(seconds: 4));

        final remoteMembers = (res as List).map((json) {
          final profile = json['profiles'] as Map<String, dynamic>?;
          final map = Map<String, dynamic>.from(json);
          if (profile != null && (profile['display_name'] as String?)?.isNotEmpty == true) {
            map['display_name'] = profile['display_name'];
          }
          return VaultMember.fromJson(map);
        }).toList();

        for (final rm in remoteMembers) {
          final rmName = (rm.displayName ?? '').trim().toLowerCase();
          final rmEmail = (rm.email ?? '').trim().toLowerCase();
          final idx = _localMembers.indexWhere((m) =>
            m.id == rm.id ||
            (m.vaultId == rm.vaultId && (
              m.userId == rm.userId ||
              (rmName.isNotEmpty && (m.displayName ?? '').trim().toLowerCase() == rmName) ||
              (rmEmail.isNotEmpty && (m.email ?? '').trim().toLowerCase() == rmEmail)
            ))
          );
          if (idx != -1) {
            _localMembers[idx] = rm.copyWith(
              id: _localMembers[idx].id,
              userId: rm.userId.isNotEmpty ? rm.userId : _localMembers[idx].userId,
              displayName: (rm.displayName != null && rm.displayName!.isNotEmpty && rm.displayName != 'Member')
                  ? rm.displayName
                  : _localMembers[idx].displayName,
            );
          } else {
            _localMembers.add(rm);
          }
        }
        await _persist();
      } catch (_) {
        // Offline / timeout: continue with local cached members
      }
    }

    final accounts = await SecureStorageService.getLocalAccounts();
    final realAdminAcc = accounts.where((a) => (a['role'] as String? ?? '').toUpperCase() == 'ADMIN').firstOrNull
        ?? accounts.firstOrNull;

    // Dynamically resolve admin name from vault name (e.g. "Deb's Family Vault" -> "Deb") or account
    final vault = _localVaults.where((v) => v.id == vaultId).firstOrNull;
    String? adminNameFromVault;
    if (vault != null && vault.name.isNotEmpty) {
      final match = RegExp(r"^(.+?)'s\s+", caseSensitive: false).firstMatch(vault.name);
      if (match != null && match.group(1)!.trim().isNotEmpty) {
        adminNameFromVault = match.group(1)!.trim();
      }
    }
    final resolvedAdminName = adminNameFromVault ??
        ((realAdminAcc != null && (realAdminAcc['displayName'] as String? ?? '').isNotEmpty)
            ? realAdminAcc['displayName'] as String
            : 'Admin');

    // Clean up legacy mock 'member-admin' or rebind to real registered admin
    bool changed = false;
    final existingRealOwner = _localMembers.where(
      (m) => m.vaultId == vaultId && m.role == VaultRole.owner && m.id != 'member-admin' && m.email != 'admin@keydiary.vault',
    ).firstOrNull;

    if (existingRealOwner != null) {
      final beforeCount = _localMembers.length;
      _localMembers.removeWhere(
        (m) => m.vaultId == vaultId && (m.id == 'member-admin' || m.email == 'admin@keydiary.vault'),
      );
      if (_localMembers.length != beforeCount) changed = true;
    } else if (realAdminAcc != null) {
      for (int i = 0; i < _localMembers.length; i++) {
        final m = _localMembers[i];
        if (m.vaultId == vaultId && (m.id == 'member-admin' || m.email == 'admin@keydiary.vault' || m.displayName == 'Admin')) {
          _localMembers[i] = m.copyWith(
            id: 'member-owner-$vaultId',
            userId: realAdminAcc['id'] as String,
            displayName: resolvedAdminName,
            email: realAdminAcc['email'] as String,
          );
          changed = true;
        }
      }
    }

    // Ensure owner member has the resolved dynamic admin name (e.g. Deb), NOT 'Owner', 'Admin', 'Primary Guardian', 'null'
    for (int i = 0; i < _localMembers.length; i++) {
      final m = _localMembers[i];
      if (m.vaultId == vaultId && m.role == VaultRole.owner) {
        final cur = (m.displayName ?? '').trim();
        if (cur.isEmpty || ['owner', 'admin', 'primary guardian', 'member', 'null'].contains(cur.toLowerCase())) {
          _localMembers[i] = m.copyWith(displayName: resolvedAdminName);
          changed = true;
        }
      }
    }

    if (changed) {
      await _persist();
    }

    final rawMembers = _localMembers.where((m) => m.vaultId == vaultId).toList();
    final List<VaultMember> resultMembers = [];
    final seen = <String>{};

    for (final m in rawMembers) {
      final acc = accounts.where((a) {
        final aId = a['id'] as String? ?? '';
        final aName = (a['displayName'] as String? ?? '').toLowerCase();
        final aEmail = (a['email'] as String? ?? '').toLowerCase();
        final aNorm = aName.replaceAll(RegExp(r'[^a-z0-9]'), '');

        final mName = (m.displayName ?? '').toLowerCase();
        final mEmail = (m.email ?? '').toLowerCase();
        final mNorm = mName.replaceAll(RegExp(r'[^a-z0-9]'), '');

        if (aId.isNotEmpty && aId == m.userId) return true;
        if (mName.isNotEmpty && (aName == mName || (aNorm.isNotEmpty && aNorm == mNorm))) return true;
        if (mEmail.isNotEmpty && (aEmail == mEmail || (mEmail.contains('@') && aEmail == mEmail))) return true;
        return false;
      }).firstOrNull;

      String finalName = m.displayName ?? '';
      if (acc != null && (acc['displayName'] as String? ?? '').isNotEmpty) {
        finalName = acc['displayName'] as String;
      }
      if (finalName.isEmpty || ['owner', 'admin', 'primary guardian', 'member', 'null'].contains(finalName.toLowerCase())) {
        if (m.role == VaultRole.owner) {
          finalName = resolvedAdminName;
        } else {
          final coGuardianAcc = accounts.where((a) => (a['role'] as String? ?? '').toUpperCase() == 'CO_GUARDIAN').firstOrNull;
          if (coGuardianAcc != null && (coGuardianAcc['displayName'] as String? ?? '').isNotEmpty) {
            finalName = coGuardianAcc['displayName'] as String;
          } else if (m.email != null && m.email!.contains('@')) {
            final part = m.email!.split('@').first;
            finalName = part.isNotEmpty ? (part[0].toUpperCase() + part.substring(1)) : 'Co-Guardian';
          } else {
            finalName = 'Co-Guardian';
          }
        }
      }

      VaultRole finalRole = m.role;
      if (finalName.toLowerCase().contains('child') ||
          (m.email != null && m.email!.toLowerCase().contains('child')) ||
          (acc != null && (acc['role'] as String? ?? '').toUpperCase() == 'CO_GUARDIAN')) {
        finalRole = VaultRole.member;
      }

      // Deduplicate by normalized name or userId so Child1 / Deb is never duplicated
      final key = finalName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (key.isNotEmpty && seen.contains(key)) {
        continue;
      }
      if (key.isNotEmpty) seen.add(key);

      resultMembers.add(
        m.copyWith(
          displayName: finalName,
          role: finalRole,
        ),
      );
    }

    return resultMembers;
  }

  /// Retrieves all registered Co-Guardians across local device accounts, registered users, and Supabase
  Future<List<Map<String, dynamic>>> getAllRegisteredCoGuardians() async {
    final List<Map<String, dynamic>> result = [];
    final seen = <String>{};

    void addCandidate(String id, String name, String email, String role) {
      final cleanName = name.trim();
      final key = cleanName.toLowerCase();
      if (cleanName.isEmpty || seen.contains(key)) return;
      seen.add(key);
      result.add({
        'user_id': id.isNotEmpty ? id : 'user-$key',
        'display_name': cleanName,
        'email': email.isNotEmpty ? email : AuthRepository.memberNameToEmail(cleanName),
        'role': role.isNotEmpty ? role : 'CO_GUARDIAN',
      });
    }

    // 1. From local accounts stored on device
    final accounts = await SecureStorageService.getLocalAccounts();
    for (final a in accounts) {
      final name = (a['displayName'] as String? ?? '').trim();
      final role = (a['role'] as String? ?? '').toUpperCase();
      if (role == 'CO_GUARDIAN' || role == 'MEMBER' || name.toLowerCase().contains('child') || name.toLowerCase().contains('guardian')) {
        addCandidate(a['id'] as String? ?? '', name, a['email'] as String? ?? '', role);
      }
    }

    // 2. From registered users list
    final regUsers = await AuthRepository().getRegisteredUsers();
    for (final u in regUsers) {
      if (u.isCoGuardian || u.displayName.toLowerCase().contains('child')) {
        addCandidate(u.id, u.displayName, u.email, u.role);
      }
    }

    // 3. From Supabase profiles if online
    if (SupabaseService.isInitialized) {
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('profiles')
            .select('user_id, display_name, role')
            .limit(50);
        for (final p in (res as List)) {
          final pId = p['user_id'] as String? ?? '';
          final pName = (p['display_name'] as String? ?? '').trim();
          final pRole = (p['role'] as String? ?? '').toUpperCase();
          if (pRole == 'CO_GUARDIAN' || pRole == 'MEMBER' || pName.toLowerCase().contains('child') || pName.toLowerCase().contains('guardian')) {
            addCandidate(pId, pName, '', pRole);
          }
        }
      } catch (_) {}
    }

    return result;
  }

  /// Searches for a registered user by name or email across Supabase profiles, local accounts, or local registry
  Future<Map<String, dynamic>?> findUser({
    required String query,
    List<AuthUser>? localUsers,
  }) async {
    final raw = query.trim();
    if (raw.isEmpty) return null;
    final clean = raw.toLowerCase();
    final normalized = clean.replaceAll(RegExp(r'[^a-z0-9]'), '');

    // 1. Search local accounts in SecureStorage
    final accounts = await SecureStorageService.getLocalAccounts();
    for (final a in accounts) {
      final aName = (a['displayName'] as String? ?? '').trim();
      final aEmail = (a['email'] as String? ?? '').trim();
      final aNormName = aName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final aNormEmail = aEmail.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

      if (aName.toLowerCase() == clean ||
          aEmail.toLowerCase() == clean ||
          (aNormName.isNotEmpty && aNormName == normalized) ||
          (aNormEmail.isNotEmpty && aNormEmail.startsWith(normalized))) {
        return {
          'user_id': a['id'] as String,
          'display_name': aName.isNotEmpty ? aName : 'Co-Guardian',
          'email': aEmail.isNotEmpty ? aEmail : AuthRepository.memberNameToEmail(aName),
          'role': a['role'] as String? ?? 'CO_GUARDIAN',
        };
      }
    }

    // 2. Search local users list / registered users
    final users = localUsers ?? await AuthRepository().getRegisteredUsers();
    for (final u in users) {
      final uNormName = u.displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final uNormEmail = u.email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (u.displayName.toLowerCase() == clean ||
          u.email.toLowerCase() == clean ||
          (uNormName.isNotEmpty && uNormName == normalized) ||
          (uNormEmail.isNotEmpty && uNormEmail.startsWith(normalized))) {
        return {
          'user_id': u.id,
          'display_name': u.displayName,
          'email': u.email,
          'role': u.role,
        };
      }
    }

    // 3. Search existing cached vault members
    await _ensureLoaded();
    for (final m in _localMembers) {
      final mName = (m.displayName ?? '').trim();
      final mEmail = (m.email ?? '').trim();
      final mNormName = mName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final mNormEmail = mEmail.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if ((mNormName.isNotEmpty && mNormName == normalized) ||
          (mNormEmail.isNotEmpty && mNormEmail.startsWith(normalized))) {
        return {
          'user_id': m.userId,
          'display_name': mName.isNotEmpty ? mName : 'Co-Guardian',
          'email': mEmail.isNotEmpty ? mEmail : AuthRepository.memberNameToEmail(mName),
          'role': 'CO_GUARDIAN',
        };
      }
    }

    // 4. If Supabase is connected, query profiles
    if (SupabaseService.isInitialized) {
      final client = Supabase.instance.client;
      try {
        final profile = await client
            .from('profiles')
            .select('user_id, display_name, role')
            .ilike('display_name', '%$clean%')
            .maybeSingle();
        if (profile != null) {
          final pName = (profile['display_name'] as String?)?.trim() ?? clean;
          return {
            'user_id': profile['user_id'] as String,
            'display_name': pName,
            'email': AuthRepository.memberNameToEmail(pName),
            'role': profile['role'] as String? ?? 'CO_GUARDIAN',
          };
        }
      } catch (_) {}

      try {
        final emailCandidate = AuthRepository.memberNameToEmail(clean);
        final profile = await client
            .from('profiles')
            .select('user_id, display_name, role')
            .ilike('display_name', emailCandidate.split('@').first)
            .maybeSingle();
        if (profile != null) {
          final pName = (profile['display_name'] as String?)?.trim() ?? clean;
          return {
            'user_id': profile['user_id'] as String,
            'display_name': pName,
            'email': emailCandidate,
            'role': profile['role'] as String? ?? 'CO_GUARDIAN',
          };
        }
      } catch (_) {}
    }

    return null;
  }

  Future<void> inviteMember({
    required String vaultId,
    required String invitedEmail,
    required String invitedBy,
    String? targetUserId,
    String? targetDisplayName,
    VaultRole role = VaultRole.member,
    Uint8List? vekBytes,
  }) async {
    await _ensureLoaded();
    final inviter = _localMembers.where((m) =>
        m.vaultId == vaultId &&
        (m.userId == invitedBy || (m.displayName != null && m.displayName!.toLowerCase() == invitedBy.toLowerCase()))
    ).firstOrNull;
    if (inviter != null && inviter.role != VaultRole.owner) {
      throw Exception('Co-guardians cannot invite members. Only Vault Admins have this permission.');
    }

    final effectiveUserId = targetUserId ?? 'user-member-${DateTime.now().millisecondsSinceEpoch}';
    final effectiveDisplayName = targetDisplayName ?? invitedEmail.split('@').first;
    final effectiveKey = vekBytes ?? await SecureStorageService.getVaultKey(vaultId);

    final existingIdx = _localMembers.indexWhere((m) =>
        m.vaultId == vaultId &&
        (m.userId == effectiveUserId ||
         (m.email != null && m.email!.toLowerCase() == invitedEmail.toLowerCase()) ||
         (m.displayName != null && targetDisplayName != null && m.displayName!.toLowerCase() == targetDisplayName.toLowerCase())));

    if (existingIdx != -1) {
      final existing = _localMembers[existingIdx];
      _localMembers[existingIdx] = existing.copyWith(
        userId: effectiveUserId,
        displayName: effectiveDisplayName,
        role: role,
        encryptedVaultKey: effectiveKey != null ? base64Encode(effectiveKey) : existing.encryptedVaultKey,
        email: invitedEmail,
      );
    } else {
      _localMembers.add(
        VaultMember(
          id: 'member-${DateTime.now().millisecondsSinceEpoch}',
          vaultId: vaultId,
          userId: effectiveUserId,
          role: role,
          encryptedVaultKey: effectiveKey != null ? base64Encode(effectiveKey) : '',
          keyWrapMetadata: {'local': true},
          createdAt: DateTime.now(),
          displayName: effectiveDisplayName,
          email: invitedEmail,
        ),
      );
    }
    await _persist();
    if (effectiveKey != null) {
      await SecureStorageService.saveVaultKey(vaultId, effectiveKey);
    }

    if (SupabaseService.isInitialized) {
      try {
        final client = Supabase.instance.client;
        if (targetUserId != null) {
          final existingRemote = await client
              .from('vault_members')
              .select('id')
              .eq('vault_id', vaultId)
              .eq('user_id', targetUserId)
              .maybeSingle();
          if (existingRemote == null) {
            await client.from('vault_members').insert({
              'vault_id': vaultId,
              'user_id': targetUserId,
              'role': role == VaultRole.owner ? 'OWNER' : 'MEMBER',
              'encrypted_vault_key': effectiveKey != null ? base64Encode(effectiveKey) : 'wrapped_key_placeholder',
            });
          }
        } else {
          await client.from('vault_invitations').insert({
            'vault_id': vaultId,
            'invited_email': invitedEmail,
            'role': role == VaultRole.owner ? 'OWNER' : 'MEMBER',
            'invited_by': invitedBy,
          });
        }
      } catch (_) {
        // Will sync once connected
      }
    }
  }

  Future<void> removeMember({
    required String vaultId,
    required String memberId,
  }) async {
    await _ensureLoaded();
    _localMembers.removeWhere((m) => m.id == memberId && m.vaultId == vaultId);
    await _persist();

    if (SupabaseService.isInitialized) {
      try {
        await Supabase.instance.client
            .from('vault_members')
            .delete()
            .eq('id', memberId)
            .eq('vault_id', vaultId);
      } catch (_) {}
    }
  }
}
