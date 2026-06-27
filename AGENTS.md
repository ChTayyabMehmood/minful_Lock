# AGENTS.md - Turkey Cold Block Feature

## What We Are Building

**Turkey Cold Block** (Digital Detox Mode) for the Mindful Android app.

When activated, the phone becomes a highly restricted device:
- Only user-selected "allowed" apps are accessible
- All other apps are blocked (overlay + back press)
- Grayscale mode activates (black & white screen)
- Can run as permanent toggle OR timed session
- Hard unlock requires PC via ADB command
- Can coexist with Focus Mode

## Architecture

### Data Flow
```
Flutter UI (TurkeyModeScreen)
    ↓ Riverpod StateNotifier
TurkeyModeNotifier (provider)
    ↓ Persists to DB + sends to native
MethodChannelService → FgMethodCallHandler
    ↓
RestrictionManager.updateTurkeyModeApps()
    ↓ On each app launch
isAppRestricted() → TURKEY_COLD_BLOCK if not whitelisted
    ↓
OverlayManager.showSheetOverlay() → blocks user
```

### Database
- `TurkeyModeTable` (singleton) - settings, whitelist, grayscale, streaks
- `TurkeyModeSessionsTable` - session history
- Migration: v9 → v10

### Native Android
- `RestrictionManager.kt` - add turkey mode whitelist check (HIGHEST priority)
- `GrayscaleManager.kt` - toggle system grayscale via Settings.Secure
- `AdbUnlockReceiver.kt` - receive ADB broadcast to unlock
- `TurkeyModeService.kt` - foreground service for timer + blocking

## Implementation Phases

### Phase 1: MVP (Database + Core Blocking)
1. Create TurkeyModeTable
2. Create TurkeyModeSessionsTable  
3. Update app_database.dart
4. Add DAO methods
5. Create default model + enums
6. Create GrayscaleManager.kt
7. Add TURKEY_COLD_BLOCK to RestrictionType
8. Modify RestrictionManager.kt
9. Create TurkeyModeNotifier provider
10. Add method channel methods
11. Create Turkey Mode setup screen
12. Create TurkeyModeService.kt
13. Create AdbUnlockReceiver.kt
14. Update AndroidManifest.xml
15. Register routes + navigation
16. Add to home dashboard
17. Build and verify

### Phase 2: Hard Unlock + Timer
- HMAC token auth for ADB unlock
- Session timer management
- Passphrase setup UI

### Phase 3: Hardening
- Device Admin integration
- Block Settings app during turkey mode
- Quick settings tile
- Boot receiver re-initialization
- VPN integration

## Key Files

### Dart/Flutter
- `lib/core/database/app_database.dart` - DB definition
- `lib/core/database/daos/unique_records_dao.dart` - singleton DAO
- `lib/core/database/daos/dynamic_records_dao.dart` - multi-row DAO
- `lib/core/utils/default_models_utils.dart` - default models
- `lib/core/services/method_channel_service.dart` - Flutter→Native bridge
- `lib/providers/restrictions/wellbeing_provider.dart` - reference pattern
- `lib/config/navigation/app_routes.dart` - routes
- `lib/initializer.dart` - startup initialization

### Kotlin/Android
- `android/app/src/main/java/com/mindful/android/services/tracking/RestrictionManager.kt`
- `android/app/src/main/java/com/mindful/android/enums/RestrictionType.kt`
- `android/app/src/main/java/com/mindful/android/FgMethodCallHandler.kt`
- `android/app/src/main/java/com/mindful/android/AppConstants.kt`
- `android/app/src/main/AndroidManifest.xml`

## Build Command
```bash
cd /home/mrhacker/Downloads/Mindful-main
flutter pub get
dart run build_runner build -d
```

## Notes
- Grayscale requires WRITE_SECURE_SETTINGS (one-time ADB grant)
- ADB unlock: `adb shell am broadcast -a com.mindful.android.action.UNLOCK_TURKEY_MODE`
- Turkey mode is additive - works alongside Focus Mode
- Whitelist = only these apps allowed; everything else blocked
