import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/network/supabase_client.dart';
import 'features/auth/data/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Attempt backend initialization from environment if configured
  await SupabaseService.initialize();

  // Restore active user session from hardware secure enclave
  await AuthRepository.restoreSession();

  runApp(
    const ProviderScope(
      child: KeyDiaryApp(),
    ),
  );
}
