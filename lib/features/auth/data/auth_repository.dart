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

  Future<AuthUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (SupabaseService.isInitialized) {
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
    } else {
      // Local enclave mode
      _localUser = AuthUser(
        id: 'local-dad-${DateTime.now().millisecondsSinceEpoch}',
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
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user == null) throw Exception('Sign in failed. Check your email and password.');

      // Fetch profile
      String displayName = 'Dad';
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
        if (profile != null) {
          displayName = profile['display_name'] ?? 'Dad';
        }
      } catch (_) {}

      return AuthUser(id: user.id, email: email, displayName: displayName);
    } else {
      _localUser = AuthUser(
        id: 'local-dad-demo',
        email: email,
        displayName: 'Dad',
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
