import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/core/database/app_database.dart';
import 'package:mindful/core/database/daos/unique_records_dao.dart';
import 'package:mindful/core/services/drift_db_service.dart';
import 'package:mindful/core/services/method_channel_service.dart';
import 'package:mindful/core/utils/default_models_utils.dart';

final turkeyModeProvider = StateNotifierProvider<TurkeyModeNotifier, TurkeyMode>(
  (ref) => TurkeyModeNotifier(),
);

class TurkeyModeNotifier extends StateNotifier<TurkeyMode> {
  late UniqueRecordsDao _dao;
  Timer? _serviceCheckTimer;

  TurkeyModeNotifier() : super(defaultTurkeyModeModel) {
    _init();
  }

  void _init() async {
    _dao = DriftDbService.instance.driftDb.uniqueRecordsDao;
    state = await _dao.loadTurkeyMode();

    // Push passphrase hash to native on startup if one exists
    if (state.unlockToken.isNotEmpty) {
      await MethodChannelService.instance
          .storePassphraseHashDirectly(state.unlockToken);
    }

    // If this was a self-restart, push current state to native
    if (MethodChannelService.instance.isSelfRestart) {
      await _syncToNative();
    }

    // Start periodic service check if enabled
    if (state.isEnabled) {
      _startServiceCheck();
    }

    // Listen to provider and save changes to database
    addListener(
      fireImmediately: false,
      (state) {
        _dao.saveTurkeyMode(state);
      },
    );
  }

  /// Starts a periodic check to verify the native service is still running.
  void _startServiceCheck() {
    _serviceCheckTimer?.cancel();
    _serviceCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!state.isEnabled) {
        _serviceCheckTimer?.cancel();
        return;
      }
      final isRunning =
          await MethodChannelService.instance.isTurkeyModeServiceRunning();
      if (!isRunning && state.isEnabled) {
        // Service stopped externally (ADB unlock or timer expiry) — disable state
        state = state.copyWith(
          isEnabled: false,
          whitelistedApps: [],
          isSessionBased: false,
          sessionDurationSec: 0,
        );
        await MethodChannelService.instance.updateTurkeyModeApps([]);
        _serviceCheckTimer?.cancel();
      }
    });
  }

  /// Syncs current state to the native Android side.
  Future<void> _syncToNative() async {
    if (state.isEnabled && state.whitelistedApps.isNotEmpty) {
      await MethodChannelService.instance
          .updateTurkeyModeApps(state.whitelistedApps);

      await MethodChannelService.instance.startTurkeyModeService(
        whitelistedApps: state.whitelistedApps,
        isSessionBased: state.isSessionBased,
        enableGrayscale: state.enableGrayscale,
        sessionDurationSec: state.sessionDurationSec,
      );

      _startServiceCheck();
    } else {
      await MethodChannelService.instance.updateTurkeyModeApps([]);
      await MethodChannelService.instance.stopTurkeyModeService();
      _serviceCheckTimer?.cancel();
    }
  }

  /// Enables turkey mode with the given whitelisted apps and syncs to native.
  Future<void> enableTurkeyMode({
    required List<String> whitelistedApps,
    required bool isSessionBased,
    int sessionDurationSec = 0,
  }) async {
    state = state.copyWith(
      isEnabled: true,
      whitelistedApps: whitelistedApps,
      isSessionBased: isSessionBased,
      sessionDurationSec: sessionDurationSec,
      sessionStartDateTime: DateTime.now(),
    );
    await _syncToNative();
  }

  /// Disables turkey mode and syncs to native.
  Future<void> disableTurkeyMode() async {
    state = state.copyWith(
      isEnabled: false,
      whitelistedApps: [],
      isSessionBased: false,
      sessionDurationSec: 0,
    );
    await _syncToNative();
  }

  /// Updates the whitelisted apps list.
  void updateWhitelistedApps(List<String> apps) {
    state = state.copyWith(whitelistedApps: apps);
  }

  /// Adds or removes an app from the whitelist.
  void toggleAppInWhitelist(String packageName) {
    final currentApps = List<String>.from(state.whitelistedApps);
    if (currentApps.contains(packageName)) {
      currentApps.remove(packageName);
    } else {
      currentApps.add(packageName);
    }
    state = state.copyWith(whitelistedApps: currentApps);
  }

  /// Sets the session duration in seconds.
  void setSessionDuration(int durationSec) {
    state = state.copyWith(sessionDurationSec: durationSec);
  }

  /// Sets the unlock passphrase: sends it to native for SHA-256 hashing,
  /// stores the returned hash, and syncs to native SharedPreferences.
  Future<String> setPassphrase(String passphrase) async {
    final hash =
        await MethodChannelService.instance.setUnlockPassphraseHash(passphrase);
    state = state.copyWith(unlockToken: hash);
    return hash;
  }

  /// Toggles grayscale mode setting.
  void toggleGrayscaleSetting() {
    state = state.copyWith(enableGrayscale: !state.enableGrayscale);
  }

  /// Updates streaks (called when a session completes successfully).
  void updateStreaks() {
    final now = DateTime.now();
    final lastUpdated = state.lastTimeStreakUpdated;
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(lastUpdated.year, lastUpdated.month, lastUpdated.day);

    int newStreak = state.currentStreak;

    if (today.difference(lastDay).inDays == 1) {
      newStreak = state.currentStreak + 1;
    } else if (today.difference(lastDay).inDays > 1) {
      newStreak = 1;
    } else if (lastDay == today) {
      newStreak = state.currentStreak > 0 ? state.currentStreak : 1;
    } else {
      newStreak = 1;
    }

    final newLongest = newStreak > state.longestStreak ? newStreak : state.longestStreak;

    state = state.copyWith(
      currentStreak: newStreak,
      longestStreak: newLongest,
      lastTimeStreakUpdated: now,
    );
  }

  @override
  void dispose() {
    _serviceCheckTimer?.cancel();
    super.dispose();
  }
}
