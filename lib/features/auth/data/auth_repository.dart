import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';

class AuthUser {
  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
  });
}

/// Authentication and Profile Repository
class AuthRepository {
  // Local fallback user when running offline or without live Supabase connection
  AuthUser? _localUser;

  AuthUser? get currentUser {
    if (SupabaseService.isInitialized) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        return AuthUser(
          id: user.id,
          email: user.email ?? '',
          displayName: user.userMetadata?['display_name'] as String? ?? 'Dad',
        );
      }
    }
    return _localUser;
  }

  bool get isAuthenticated => currentUser != null;

  /// Converts a member name into a valid, deterministic vault email format for Supabase Auth
  static String memberNameToEmail(String memberName) {
    final clean = memberName.trim();
    if (clean.contains('@')) {
      return clean.toLowerCase();
    }
    final sanitized = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final safe = sanitized.isEmpty ? 'member' : sanitized;
    return '$safe@keydiary.vault';
  }

  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (SupabaseService.isInitialized) {
      try {
        final res = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'display_name': displayName},
        );
        final user = res.user;
        if (user == null) throw Exception('Registration failed.');

        // Create profile in profiles table
        try {
          await Supabase.instance.client.from('profiles').insert({
            'user_id': user.id,
            'display_name': displayName,
          });
        } catch (_) {}

        return AuthUser(id: user.id, email: email, displayName: displayName);
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
    } else {
      // Local enclave mode
      _localUser = AuthUser(
        id: 'local-member-${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        displayName: displayName,
      );
      return _localUser!;
    }
  }

  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    if (SupabaseService.isInitialized) {
      try {
        final res = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        final user = res.user;
        if (user == null) throw Exception('Sign in failed. Check your member name and password.');

        // Fetch profile
        String displayName = 'Member';
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();
          if (profile != null) {
            displayName = profile['display_name'] ?? 'Member';
          }
        } catch (_) {}

        return AuthUser(id: user.id, email: email, displayName: displayName);
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
      _localUser = AuthUser(
        id: 'local-member-demo',
        email: email,
        displayName: email.contains('@') ? email.split('@').first : 'Member',
      );
      return _localUser!;
    }
  }

  Future<void> signOut() async {
    if (SupabaseService.isInitialized) {
      await Supabase.instance.client.auth.signOut();
    }
    _localUser = null;
  }
}
