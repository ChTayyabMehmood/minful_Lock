// ignore_for_file: file_names

import 'package:drift/drift.dart';
import 'package:mindful/core/database/schemas/schema_versions.dart';
import 'package:mindful/core/utils/db_utils.dart';

Future<void> from9To10(Migrator m, Schema10 schema) async => await runSafe(
      "Migration(9 to 10)",
      () async {
        /// Create [TurkeyModeTable] for turkey mode settings
        await m.createTable(schema.turkeyModeTable);

        /// Create [TurkeyModeSessionsTable] for session history
        await m.createTable(schema.turkeyModeSessionsTable);
      },
    );
