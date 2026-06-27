import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/core/database/app_database.dart';
import 'package:mindful/core/extensions/ext_build_context.dart';
import 'package:mindful/core/extensions/ext_num.dart';
import 'package:mindful/core/services/method_channel_service.dart';
import 'package:mindful/models/app_info.dart';
import 'package:mindful/providers/apps/apps_info_provider.dart';
import 'package:mindful/providers/restrictions/turkey_mode_provider.dart';
import 'package:mindful/ui/common/default_list_tile.dart';
import 'package:mindful/ui/common/rounded_container.dart';
import 'package:mindful/ui/common/styled_text.dart';
import 'package:mindful/ui/common/content_section_header.dart';

class TurkeyModeScreen extends ConsumerStatefulWidget {
  const TurkeyModeScreen({super.key});

  @override
  ConsumerState<TurkeyModeScreen> createState() => _TurkeyModeScreenState();
}

class _TurkeyModeScreenState extends ConsumerState<TurkeyModeScreen> {
  String _searchQuery = '';
  bool _hasGrayscalePermission = false;
  bool _obscurePassphrase = true;
  final _passphraseController = TextEditingController();

  static const _sessionDurations = [
    (label: '15 min', value: 900),
    (label: '30 min', value: 1800),
    (label: '1 hour', value: 3600),
    (label: '2 hours', value: 7200),
    (label: '4 hours', value: 14400),
    (label: '8 hours', value: 28800),
  ];

  @override
  void initState() {
    super.initState();
    _checkGrayscalePermission();
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _checkGrayscalePermission() async {
    final hasPermission =
        await MethodChannelService.instance.hasWriteSecureSettings();
    setState(() => _hasGrayscalePermission = hasPermission);
  }

  /// Computes remaining time for a session-based turkey mode.
  String _computeRemainingTime(TurkeyMode turkeyMode) {
    if (!turkeyMode.isEnabled || !turkeyMode.isSessionBased || turkeyMode.sessionDurationSec <= 0) {
      return '';
    }
    final elapsed = DateTime.now().difference(turkeyMode.sessionStartDateTime).inSeconds;
    final remaining = turkeyMode.sessionDurationSec - elapsed;
    if (remaining <= 0) return 'Expired';
    final hours = remaining ~/ 3600;
    final mins = (remaining % 3600) ~/ 60;
    final secs = remaining % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final turkeyMode = ref.watch(turkeyModeProvider);
    final appsMap = ref.watch(appsInfoProvider);
    final whitelistedApps = turkeyMode.whitelistedApps;

    final allApps = appsMap.value?.values.toList() ?? [];
    final filteredApps = _searchQuery.isEmpty
        ? allApps
        : allApps
            .where((app) =>
                app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                app.packageName
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
            .toList();

    final sortedApps = List<AppInfo>.from(filteredApps);
    sortedApps.sort((a, b) {
      final aSelected = whitelistedApps.contains(a.packageName);
      final bSelected = whitelistedApps.contains(b.packageName);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return a.name.compareTo(b.name);
    });

    return Scaffold(
      appBar: AppBar(
        title: StyledText(
          turkeyMode.isEnabled ? 'Turkey Mode Active' : 'Turkey Mode',
          fontWeight: FontWeight.bold,
        ),
        actions: [
          if (turkeyMode.isEnabled)
            IconButton(
              icon: const Icon(FluentIcons.stop_20_filled),
              onPressed: () => _showStopDialog(context, ref),
              tooltip: 'Stop Turkey Mode',
            ),
          if (!turkeyMode.isEnabled)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await ref.read(turkeyModeProvider.notifier).disableTurkeyMode();
                ref.invalidate(turkeyModeProvider);
              },
              tooltip: 'Reset state from device',
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Status card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildStatusCard(context, ref, turkeyMode),
            ),
          ),

          // Settings section
          const SliverToBoxAdapter(
            child: ContentSectionHeader(title: 'Settings'),
          ),

          // Mode toggle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RoundedContainer(
                padding: const EdgeInsets.all(4),
                child: SwitchListTile(
                  title: const StyledText(
                    'Enable Turkey Mode',
                    fontWeight: FontWeight.w600,
                  ),
                  subtitle: StyledText(
                    turkeyMode.isEnabled
                        ? 'Active - blocking non-whitelisted apps'
                        : 'Tap to activate digital detox',
                    fontSize: 12,
                  ),
                  value: turkeyMode.isEnabled,
                  onChanged: (value) {
                    if (value) {
                      _showEnableDialog(context, ref, turkeyMode);
                    } else {
                      _showStopDialog(context, ref);
                    }
                  },
                ),
              ),
            ),
          ),

          // Session mode
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: RoundedContainer(
                padding: const EdgeInsets.all(4),
                child: SwitchListTile(
                  title: const StyledText(
                    'Session Mode (Timer)',
                    fontWeight: FontWeight.w600,
                  ),
                  subtitle: StyledText(
                    turkeyMode.isSessionBased
                        ? 'Will auto-disable after duration'
                        : 'Stays on until manually disabled',
                    fontSize: 12,
                  ),
                  value: turkeyMode.isSessionBased,
                  onChanged: turkeyMode.isEnabled
                      ? null
                      : (value) {
                          ref.read(turkeyModeProvider.notifier).state =
                              turkeyMode.copyWith(isSessionBased: value);
                        },
                ),
              ),
            ),
          ),

          // Session duration picker (only visible when session mode is on)
          if (turkeyMode.isSessionBased && !turkeyMode.isEnabled)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: RoundedContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const StyledText(
                        'Session Duration',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      8.vBox,
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _sessionDurations.map((d) {
                            final selected = turkeyMode.sessionDurationSec == d.value;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: StyledText(d.label, fontSize: 13),
                                selected: selected,
                                onSelected: (_) {
                                  ref
                                      .read(turkeyModeProvider.notifier)
                                      .setSessionDuration(d.value);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Grayscale toggle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: RoundedContainer(
                padding: const EdgeInsets.all(4),
                child: SwitchListTile(
                  title: const StyledText(
                    'Grayscale Mode',
                    fontWeight: FontWeight.w600,
                  ),
                  subtitle: StyledText(
                    _hasGrayscalePermission
                        ? 'Screen becomes black & white'
                        : 'Requires ADB: pm grant WRITE_SECURE_SETTINGS',
                    fontSize: 12,
                    color: _hasGrayscalePermission ? null : Colors.orange,
                  ),
                  value: turkeyMode.enableGrayscale,
                  onChanged: turkeyMode.isEnabled
                      ? null
                      : (value) {
                          ref
                              .read(turkeyModeProvider.notifier)
                              .toggleGrayscaleSetting();
                        },
                ),
              ),
            ),
          ),

          // Passphrase section (only when turkey mode is not active)
          if (!turkeyMode.isEnabled)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: RoundedContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(FluentIcons.lock_closed_20_regular, size: 18),
                          4.hBox,
                          const Expanded(
                            child: StyledText(
                              'PC Unlock Passphrase',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Switch(
                            value: turkeyMode.requirePcUnlock,
                            onChanged: (v) {
                              ref.read(turkeyModeProvider.notifier).state =
                                  turkeyMode.copyWith(requirePcUnlock: v);
                            },
                          ),
                        ],
                      ),
                      if (turkeyMode.requirePcUnlock) ...[
                        8.vBox,
                        StyledText(
                          'Set a passphrase to unlock Turkey Mode from your PC via ADB.',
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        8.vBox,
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _passphraseController,
                                obscureText: _obscurePassphrase,
                                decoration: InputDecoration(
                                  hintText: 'Enter passphrase',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassphrase
                                          ? FluentIcons.eye_20_regular
                                          : FluentIcons.eye_off_20_regular,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscurePassphrase = !_obscurePassphrase),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            8.hBox,
                            FilledButton.tonalIcon(
                              onPressed: _passphraseController.text.isEmpty
                                  ? null
                                  : () async {
                                      final notifier =
                                          ref.read(turkeyModeProvider.notifier);
                                      await notifier
                                          .setPassphrase(_passphraseController.text);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Passphrase set'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                              icon: const Icon(FluentIcons.checkmark_20_regular, size: 16),
                              label: const StyledText('Set', fontSize: 13),
                            ),
                          ],
                        ),
                        // Show ADB command if hash is set
                        if (turkeyMode.unlockToken.isNotEmpty &&
                            _passphraseController.text.isNotEmpty) ...[
                          12.vBox,
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(FluentIcons.lock_closed_20_regular,
                                        size: 16),
                                    4.hBox,
                                    const StyledText(
                                      'ADB Unlock Command',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(FluentIcons.copy_20_regular,
                                          size: 16),
                                      tooltip: 'Copy command',
                                      onPressed: () {
                                        final cmd =
                                            'adb shell am broadcast -a com.mindful.android.action.UNLOCK_TURKEY_MODE --es token "${_passphraseController.text}" -n com.mindful.android/.receivers.AdbUnlockReceiver';
                                        Clipboard.setData(
                                            ClipboardData(text: cmd));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('ADB command copied'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                4.vBox,
                                SelectableText(
                                  'adb shell am broadcast -a com.mindful.android.action.UNLOCK_TURKEY_MODE --es token "${_passphraseController.text}" -n com.mindful.android/.receivers.AdbUnlockReceiver',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Whitelist section header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: ContentSectionHeader(title: 'Allowed Apps (Whitelist)'),
            ),
          ),

          // Whitelist counter
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: StyledText(
                '${whitelistedApps.length} of ${allApps.length} apps allowed',
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search apps...',
                  prefixIcon: const Icon(FluentIcons.search_20_regular),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(FluentIcons.dismiss_20_regular),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),

          // App list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final app = sortedApps[index];
                final isWhitelisted =
                    whitelistedApps.contains(app.packageName);

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: DefaultListTile(
                    leading: app.icon.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              app.icon,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(FluentIcons.phone_20_regular, size: 40),
                    titleText: app.name,
                    subtitleText: app.packageName,
                    trailing: Icon(
                      isWhitelisted
                          ? FluentIcons.checkmark_circle_20_filled
                          : FluentIcons.circle_20_regular,
                      color: isWhitelisted
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    isSelected: isWhitelisted,
                    onPressed: () {
                      ref
                          .read(turkeyModeProvider.notifier)
                          .toggleAppInWhitelist(app.packageName);
                    },
                  ),
                );
              },
              childCount: sortedApps.length,
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
      BuildContext context, WidgetRef ref, TurkeyMode turkeyMode) {
    final colorScheme = Theme.of(context).colorScheme;
    final remainingTime = _computeRemainingTime(turkeyMode);

    return RoundedContainer(
      padding: const EdgeInsets.all(16),
      color: turkeyMode.isEnabled
          ? colorScheme.errorContainer.withOpacity(0.3)
          : colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                FluentIcons.phone_20_filled,
                color: turkeyMode.isEnabled
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
                size: 24,
              ),
              8.hBox,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StyledText(
                      turkeyMode.isEnabled ? 'Active' : 'Inactive',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: turkeyMode.isEnabled
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                    ),
                    StyledText(
                      turkeyMode.isEnabled
                          ? '${turkeyMode.whitelistedApps.length} apps whitelisted'
                          : 'Select apps and enable to start',
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (turkeyMode.isEnabled && remainingTime.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(FluentIcons.timer_20_regular, size: 16),
                4.hBox,
                StyledText(
                  'Time remaining: $remainingTime',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.error,
                ),
              ],
            ),
          ],
          if (turkeyMode.currentStreak > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(FluentIcons.fire_20_filled, size: 16),
                4.hBox,
                StyledText(
                  'Streak: ${turkeyMode.currentStreak} days | Best: ${turkeyMode.longestStreak} days',
                  fontSize: 12,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showEnableDialog(
      BuildContext context, WidgetRef ref, TurkeyMode turkeyMode) {
    if (turkeyMode.whitelistedApps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please select at least one app in the whitelist before enabling.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (turkeyMode.requirePcUnlock && turkeyMode.unlockToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please set a PC unlock passphrase before enabling.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (turkeyMode.isSessionBased && turkeyMode.sessionDurationSec <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please select a session duration before enabling.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Turkey Mode?'),
        content: Text(
          'This will block all apps except ${turkeyMode.whitelistedApps.length} whitelisted apps.'
          '${turkeyMode.enableGrayscale ? '\n\nGrayscale mode will be enabled.' : ''}'
          '${turkeyMode.isSessionBased && turkeyMode.sessionDurationSec > 0 ? '\n\nSession duration: ${turkeyMode.sessionDurationSec ~/ 60} minutes.' : ''}'
          '${turkeyMode.requirePcUnlock ? '\n\nTo disable, you must connect to your PC and run the ADB unlock command.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(turkeyModeProvider.notifier).enableTurkeyMode(
                    whitelistedApps: turkeyMode.whitelistedApps,
                    isSessionBased: turkeyMode.isSessionBased,
                    sessionDurationSec: turkeyMode.sessionDurationSec,
                  );
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  void _showStopDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Turkey Mode?'),
        content: const Text(
          'Are you sure you want to disable Turkey Mode? All blocked apps will become accessible again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(turkeyModeProvider.notifier).disableTurkeyMode();
            },
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}
