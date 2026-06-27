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

@DataClassName("TurkeyModeSession")
class TurkeyModeSessionsTable extends Table {
  /// Auto-incrementing primary key
  IntColumn get id => integer().autoIncrement()();

  /// Whether this was a session-based (timed) or permanent session
  BoolColumn get isSessionBased =>
      boolean().withDefault(const Constant(false))();

  /// When the session started
  DateTimeColumn get startDateTime =>
      dateTime().withDefault(Constant(DateTime(0)))();

  /// When the session ended (0 if still active)
  DateTimeColumn get endDateTime =>
      dateTime().withDefault(Constant(DateTime(0)))();

  /// Duration in seconds
  IntColumn get durationSecs => integer().withDefault(const Constant(0))();

  /// Whether the session completed successfully (not forcibly stopped)
  BoolColumn get wasSuccessful =>
      boolean().withDefault(const Constant(true))();

  /// Whitelisted apps during this session (JSON list)
  TextColumn get whitelistedApps => text()
      .map(const StringListConverter())
      .withDefault(Constant(jsonEncode([])))();
}
