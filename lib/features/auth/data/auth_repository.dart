import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/security/secure_storage_service.dart';

class AuthUser {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String role; // 'ADMIN' or 'CO_GUARDIAN'

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.role = 'ADMIN',
  });

  bool get isCoGuardian =>
      role.toUpperCase() == 'CO_GUARDIAN' ||
      role.toUpperCase() == 'MEMBER' ||
      displayName.trim().toLowerCase().contains('child');
  bool get isAdmin => !isCoGuardian;
}

/// Helper for PBKDF2-HMAC-SHA256 password hashing with random salt
class PasswordHelper {
  static const int _iterations = 10000;

  static Future<String> hashPassword(String password) async {
    final random = Random.secure();
    final salt = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      salt[i] = random.nextInt(256);
    }
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    );
    final secretKey = SecretKey(utf8.encode(password));
    final derivedKey = await pbkdf2.deriveKey(secretKey: secretKey, nonce: salt);
    final hashBytes = await derivedKey.extractBytes();
    return '${base64Encode(salt)}\$${base64Encode(hashBytes)}';
  }

  static Future<bool> verifyPassword(String enteredPassword, String storedHash) async {
    try {
      final parts = storedHash.split('\$');
      if (parts.length != 2) return false;
      final salt = base64Decode(parts[0]);
      final expectedHash = base64Decode(parts[1]);
      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _iterations,
        bits: 256,
      );
      final secretKey = SecretKey(utf8.encode(enteredPassword));
      final derivedKey = await pbkdf2.deriveKey(secretKey: secretKey, nonce: salt);
      final derivedBytes = await derivedKey.extractBytes();

      if (derivedBytes.length != expectedHash.length) return false;
      int diff = 0;
      for (int i = 0; i < derivedBytes.length; i++) {
        diff |= derivedBytes[i] ^ expectedHash[i];
      }
      return diff == 0;
    } catch (_) {
      return false;
    }
  }
}

/// Authentication and Profile Repository
class AuthRepository {
  // Local fallback user when running offline or without live Supabase connection
  static AuthUser? _localUser;

  /// Restores session on app startup / hot restart
  static Future<void> restoreSession() async {
    final session = await SecureStorageService.getUserSession();
    if (session != null && session['id'] != null && session['id']!.isNotEmpty) {
      String displayName = session['displayName'] ?? '';
      String role = session['role'] ?? '';
      final email = session['email'] ?? '';

      if ((displayName.isEmpty || displayName == 'Member') && email.contains('@')) {
        final prefix = email.split('@').first;
        displayName = prefix.isNotEmpty ? (prefix[0].toUpperCase() + prefix.substring(1)) : '';
      }
      if (displayName.toLowerCase().contains('child') || displayName.toLowerCase().contains('guardian')) {
        role = 'CO_GUARDIAN';
      }
      if (role.isEmpty) {
        role = (displayName.toLowerCase().contains('child') || displayName.toLowerCase().contains('guardian')) ? 'CO_GUARDIAN' : 'ADMIN';
      }

      _localUser = AuthUser(
        id: session['id']!,
        email: email,
        displayName: displayName.isNotEmpty ? displayName : 'Member',
        role: role,
      );
    }
  }

  List<AuthUser> get registeredUsers => _localUser != null ? [_localUser!] : [];

  Future<List<AuthUser>> getRegisteredUsers() async {
    final accounts = await SecureStorageService.getLocalAccounts();
    return accounts.map((a) {
      final name = a['displayName'] as String? ?? '';
      final email = a['email'] as String? ?? '';
      String effectiveName = name;
      if ((effectiveName.isEmpty || effectiveName == 'Member') && email.contains('@')) {
        final prefix = email.split('@').first;
        effectiveName = prefix.isNotEmpty ? (prefix[0].toUpperCase() + prefix.substring(1)) : '';
      }
      String role = a['role'] as String? ?? '';
      if (role.isEmpty && (effectiveName.toLowerCase().contains('child') || effectiveName.toLowerCase().contains('guardian'))) {
        role = 'CO_GUARDIAN';
      } else if (role.isEmpty) {
        role = 'ADMIN';
      }
      return AuthUser(
        id: a['id'] as String? ?? '',
        email: email,
        displayName: effectiveName.isNotEmpty ? effectiveName : 'Member',
        role: role,
      );
    }).toList();
  }

  AuthUser? get currentUser {
    if (SupabaseService.isInitialized) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        String? metaName = user.userMetadata?['display_name'] as String?;
        String? metaRole = user.userMetadata?['role'] as String?;

        String displayName = (metaName != null && metaName.trim().isNotEmpty) ? metaName.trim() : '';
        String role = (metaRole != null && metaRole.trim().isNotEmpty) ? metaRole.toUpperCase() : '';

        if (_localUser != null && (_localUser!.id == user.id || _localUser!.email == user.email)) {
          if (displayName.isEmpty || displayName == 'Member') {
            displayName = _localUser!.displayName;
          }
          if (role.isEmpty) {
            role = _localUser!.role;
          }
        }

        if ((displayName.isEmpty || displayName == 'Member') && user.email != null && user.email!.contains('@')) {
          final prefix = user.email!.split('@').first;
          if (prefix.isNotEmpty) {
            displayName = prefix[0].toUpperCase() + prefix.substring(1);
          }
        }

        if (displayName.toLowerCase().contains('child') || displayName.toLowerCase().contains('guardian')) {
          role = 'CO_GUARDIAN';
        } else if (role.isEmpty) {
          role = 'ADMIN';
        }

        return AuthUser(
          id: user.id,
          email: user.email ?? '',
          displayName: displayName.isNotEmpty ? displayName : 'Member',
          role: role,
        );
      }
    }
    return _localUser;
  }

  bool get isAuthenticated => currentUser != null;

  /// Standard member email format for zero-email signin
  static String memberNameToEmail(String name) {
    final clean = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$clean@keydiary.vault';
  }

  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
    String role = 'ADMIN',
  }) async {
    if (password.length < 6) {
      throw Exception('Password is too short (must be at least 6 characters).');
    }

    final cleanName = displayName.trim();
    final cleanEmail = email.trim().toLowerCase();

    // ALWAYS store the registered account in local accounts so findUser & getRegisteredUsers find it immediately
    final accounts = await SecureStorageService.getLocalAccounts();
    final existingIdx = accounts.indexWhere((a) =>
        (a['email'] as String? ?? '').toLowerCase() == cleanEmail ||
        (a['displayName'] as String? ?? '').toLowerCase() == cleanName.toLowerCase());

    String userId = existingIdx != -1 ? (accounts[existingIdx]['id'] as String) : const Uuid().v4();
    final passwordHash = await PasswordHelper.hashPassword(password);

    if (SupabaseService.isInitialized) {
      try {
        final res = await Supabase.instance.client.auth.signUp(
          email: cleanEmail,
          password: password,
          data: {'display_name': cleanName, 'role': role},
        );
        final user = res.user;
        if (user != null) {
          userId = user.id;
        }

        // Create or upsert profile in profiles table
        try {
          await Supabase.instance.client.from('profiles').upsert({
            'user_id': userId,
            'display_name': cleanName,
            'role': role,
          });
        } catch (_) {}
      } on AuthApiException catch (e) {
        if (e.message.toLowerCase().contains('already registered')) {
          throw Exception('A vault member with this name already exists. Please sign in instead.');
        } else if (e.message.toLowerCase().contains('password')) {
          throw Exception('Password is too short (must be at least 6 characters).');
        }
        throw Exception(e.message);
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('socketfailed') || errStr.contains('host lookup') || errStr.contains('errno = 7')) {
          throw Exception('Cannot connect to Supabase server. Please verify your internet connection or check your Supabase project URL.');
        }
        rethrow;
      }
    }

    final accountData = {
      'id': userId,
      'email': cleanEmail,
      'displayName': cleanName,
      'passwordHash': passwordHash,
      'role': role,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (existingIdx != -1) {
      accounts[existingIdx] = accountData;
    } else {
      accounts.add(accountData);
    }
    await SecureStorageService.saveLocalAccounts(accounts);

    _localUser = AuthUser(
      id: userId,
      email: cleanEmail,
      displayName: cleanName,
      role: role,
    );
    await SecureStorageService.saveUserSession(
      id: userId,
      email: cleanEmail,
      displayName: cleanName,
      role: role,
    );

    return _localUser!;
  }

  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    if (password.isEmpty) {
      throw Exception('Please enter your vault password.');
    }

    if (SupabaseService.isInitialized) {
      try {
        final res = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        final user = res.user;
        if (user == null) throw Exception('Sign in failed. Check your member name and password.');

        String displayName = (user.userMetadata?['display_name'] as String?)?.trim() ?? '';
        String role = (user.userMetadata?['role'] as String?)?.toUpperCase() ?? '';

        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();
          if (profile != null) {
            if (profile['display_name'] != null && (profile['display_name'] as String).trim().isNotEmpty) {
              displayName = (profile['display_name'] as String).trim();
            }
            if (profile['role'] != null && (profile['role'] as String).isNotEmpty) {
              role = (profile['role'] as String).toUpperCase();
            }
          }
        } catch (_) {}

        final accounts = await SecureStorageService.getLocalAccounts();
        final localAcc = accounts.where((a) =>
            a['id'] == user.id ||
            (a['email'] as String? ?? '').toLowerCase() == email.trim().toLowerCase()
        ).firstOrNull;

        if (localAcc != null) {
          if (displayName.isEmpty && localAcc['displayName'] != null) {
            displayName = localAcc['displayName'] as String;
          }
          if (role.isEmpty && localAcc['role'] != null) {
            role = localAcc['role'] as String;
          }
        }

        if ((displayName.isEmpty || displayName == 'Member') && email.contains('@')) {
          displayName = email.split('@').first;
          if (displayName.isNotEmpty) {
            displayName = displayName[0].toUpperCase() + displayName.substring(1);
          }
        }
        if (displayName.toLowerCase().contains('child') || displayName.toLowerCase().contains('guardian') || role == 'CO_GUARDIAN') {
          role = 'CO_GUARDIAN';
        } else if (role.isEmpty) {
          role = 'ADMIN';
        }

        final existingIdx = accounts.indexWhere((a) =>
            a['id'] == user.id ||
            (a['email'] as String? ?? '').toLowerCase() == email.trim().toLowerCase()
        );
        final accountData = {
          'id': user.id,
          'email': email.trim().toLowerCase(),
          'displayName': displayName,
          'role': role,
          'createdAt': DateTime.now().toIso8601String(),
        };
        if (existingIdx != -1) {
          accounts[existingIdx] = accountData;
        } else {
          accounts.add(accountData);
        }
        await SecureStorageService.saveLocalAccounts(accounts);
        await SecureStorageService.saveUserSession(
          id: user.id,
          email: email.trim().toLowerCase(),
          displayName: displayName,
          role: role,
        );

        _localUser = AuthUser(id: user.id, email: email, displayName: displayName, role: role);
        return _localUser!;
      } on AuthApiException catch (e) {
        if (e.message.toLowerCase().contains('invalid login credentials') || e.message.toLowerCase().contains('invalid grant')) {
          throw Exception('Incorrect member name or password. Please verify and try again.');
        }
        throw Exception(e.message);
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('socketfailed') || errStr.contains('host lookup') || errStr.contains('errno = 7')) {
          throw Exception('Cannot connect to Supabase server. Please check your internet connection.');
        }
        rethrow;
      }
    } else {
      // Local secure enclave verification
      final cleanEmail = email.trim().toLowerCase();
      final memberLookup = cleanEmail.contains('@') ? cleanEmail.split('@').first : cleanEmail;

      final accounts = await SecureStorageService.getLocalAccounts();
      final account = accounts.where((a) {
        final aEmail = (a['email'] as String? ?? '').toLowerCase();
        final aName = (a['displayName'] as String? ?? '').toLowerCase();
        return aEmail == cleanEmail || aName == memberLookup;
      }).firstOrNull;

      if (account == null) {
        throw Exception('No vault account found for "$memberLookup". Please tap "Create Family Vault" below.');
      }

      final storedHash = account['passwordHash'] as String? ?? '';
      final isValidPassword = await PasswordHelper.verifyPassword(password, storedHash);
      if (!isValidPassword) {
        throw Exception('Incorrect password. Please verify and try again.');
      }

      final role = account['role'] as String? ?? 'ADMIN';
      final user = AuthUser(
        id: account['id'] as String,
        email: account['email'] as String,
        displayName: account['displayName'] as String? ?? memberLookup,
        role: role,
      );

      _localUser = user;
      await SecureStorageService.saveUserSession(
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        role: role,
      );

      return user;
    }
  }

  Future<void> signOut() async {
    if (SupabaseService.isInitialized) {
      await Supabase.instance.client.auth.signOut();
    }
    _localUser = null;
    await SecureStorageService.clearUserSession();
  }
}
