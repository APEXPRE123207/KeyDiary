import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import 'secure_storage_service.dart';

/// Monitors AppLifecycleState to enforce auto-lock after background timeout
class AutoLockManager with WidgetsBindingObserver {
  final WidgetRef ref;
  DateTime? _pausedAt;

  AutoLockManager(this.ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkAndLockIfNeeded();
    }
  }

  Future<void> _checkAndLockIfNeeded() async {
    if (_pausedAt == null) return;
    final timeoutSeconds = await SecureStorageService.getAutoLockSeconds();

    if (timeoutSeconds < 0) {
      // Never lock
      _pausedAt = null;
      return;
    }

    final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
    if (elapsed >= timeoutSeconds) {
      // Wipe in-memory VEK
      ref.read(vaultKeyProvider.notifier).state = null;
    }
    _pausedAt = null;
  }

  void lockNow() {
    ref.read(vaultKeyProvider.notifier).state = null;
  }
}
