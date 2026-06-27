/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:mindful/core/database/converters/string_list_converter.dart';

@DataClassName("TurkeyMode")
class TurkeyModeTable extends Table {
  /// Unique ID for turkey mode settings (singleton row)
  IntColumn get id => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>>? get primaryKey => {id};

  /// Whether turkey mode is currently enabled
  BoolColumn get isEnabled => boolean().withDefault(const Constant(false))();

  /// Whether this is a session-based (timed) or permanent mode
  BoolColumn get isSessionBased =>
      boolean().withDefault(const Constant(false))();

  /// Session duration in seconds (0 = permanent)
  IntColumn get sessionDurationSec =>
      integer().withDefault(const Constant(0))();

  /// When the current session started
  DateTimeColumn get sessionStartDateTime =>
      dateTime().withDefault(Constant(DateTime(0)))();

  /// List of whitelisted app package names (only these apps are allowed)
  TextColumn get whitelistedApps => text()
      .map(const StringListConverter())
      .withDefault(Constant(jsonEncode([])))();

  /// Whether to enable grayscale mode when turkey mode is active
  BoolColumn get enableGrayscale =>
      boolean().withDefault(const Constant(true))();

  /// Whether PC unlock is required to disable turkey mode
  BoolColumn get requirePcUnlock =>
      boolean().withDefault(const Constant(true))();

  /// Passphrase/token for ADB unlock authentication
  TextColumn get unlockToken => text().withDefault(const Constant(''))();

  /// Current consecutive-day streak
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();

  /// Longest streak ever achieved
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();

  /// Last date the streak was updated
  DateTimeColumn get lastTimeStreakUpdated =>
      dateTime().withDefault(Constant(DateTime(0)))();
}
