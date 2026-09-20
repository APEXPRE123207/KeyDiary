import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages Supabase client initialization and connection state
class SupabaseService {
  SupabaseService._();

  static bool _isInitialized = false;

  static bool get isConfigured => _isInitialized && Supabase.instance.client.auth.currentSession != null;

  static SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError('Supabase has not been initialized. Check environment credentials.');
    }
    return Supabase.instance.client;
  }

  /// Attempts initialization with environment URL and Anon key
  static Future<bool> initialize({
    String? url,
    String? anonKey,
  }) async {
    final supabaseUrl = url ?? const String.fromEnvironment('SUPABASE_URL');
    final supabaseAnonKey = anonKey ?? const String.fromEnvironment('SUPABASE_ANON_KEY');

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty || supabaseUrl.contains('your-project-ref')) {
      // Not yet configured with live backend, will operate in local secure enclave mode
      _isInitialized = false;
      return false;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
      _isInitialized = true;
      return true;
    } catch (_) {
      _isInitialized = false;
      return false;
    }
  }

  static bool get isInitialized => _isInitialized;
}
