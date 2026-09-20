import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/security/auto_lock_service.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class KeyDiaryApp extends ConsumerStatefulWidget {
  const KeyDiaryApp({super.key});

  @override
  ConsumerState<KeyDiaryApp> createState() => _KeyDiaryAppState();
}

class _KeyDiaryAppState extends ConsumerState<KeyDiaryApp> {
  late AutoLockManager _autoLockManager;

  @override
  void initState() {
    super.initState();
    _autoLockManager = AutoLockManager(ref);
  }

  @override
  void dispose() {
    _autoLockManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'KeyDiary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
