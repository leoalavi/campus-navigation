import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/app/l10n/generated/app_localizations.dart';
import 'package:mq_navigation/app/router/shell_chrome_provider.dart';
import 'package:mq_navigation/app/theme/mq_colors.dart';
import 'package:mq_navigation/app/theme/mq_spacing.dart';
import 'package:mq_navigation/features/open_day/data/open_day_providers.dart';
import 'package:mq_navigation/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_navigation/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_navigation/shared/extensions/context_extensions.dart';
import 'package:mq_navigation/shared/widgets/mq_bottom_sheet.dart';

/// Lightweight, non-blocking bachelor picker. Surfaces as a bottom sheet
/// so it never feels like an account-setup wall — the user can dismiss
/// and the app keeps working without a selection.
///
/// Bachelors are grouped under their study area for fast scanning. Tapping
/// a row immediately commits the choice (no "Save" button) — this is a
/// preference, not a form submission.
class BachelorPickerSheet extends ConsumerWidget {
  const BachelorPickerSheet({super.key});

  /// Opens the picker, hiding the shell's bottom navigation for as long as it
  /// is up so the selector owns the screen instead of floating over the tabs.
  static Future<void> show(BuildContext context, WidgetRef ref) {
    return ref
        .read(shellChromeProvider.notifier)
        .guard(
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            // Leave the status bar clear; the sheet may otherwise be allowed
            // to grow taller than the window and clip its own content.
            useSafeArea: true,
            builder: (_) => const BachelorPickerSheet(),
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final dataAsync = ref.watch(openDayDataProvider);
    final selectedId = ref
        .watch(settingsControllerProvider)
        .value
        ?.selectedBachelorId;

    // Cap against the space the sheet actually has, not a fraction of the
    // whole screen: `useSafeArea` + the sheet's own chrome already consume
    // part of the window, and the keyboard can claim more. Using
    // `size.height * 0.78` ignored all of that, which is what produced the
    // "BOTTOM OVERFLOWED BY 11 PIXELS" banner on shorter viewports.
    final media = MediaQuery.of(context);
    final available =
        media.size.height -
        media.padding.top -
        media.padding.bottom -
        media.viewInsets.bottom;
    final maxSheetHeight = (available * 0.88).clamp(200.0, available);

    return MqBottomSheet(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                MqSpacing.space2,
                0,
                MqSpacing.space2,
                MqSpacing.space2,
              ),
              child: Text(
                l10n.openDay_interestedInStudying,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white : MqColors.contentPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                MqSpacing.space2,
                0,
                MqSpacing.space2,
                MqSpacing.space4,
              ),
              child: Text(
                l10n.openDay_pickerSubtitle,
                style: context.textTheme.bodySmall?.copyWith(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.72)
                      : MqColors.contentSecondary,
                ),
              ),
            ),
            Flexible(
              child: dataAsync.when(
                data: (data) =>
                    _BachelorList(data: data, selectedId: selectedId),
                loading: () => const Padding(
                  padding: EdgeInsetsDirectional.all(MqSpacing.space6),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsetsDirectional.all(MqSpacing.space6),
                  child: Text(
                    l10n.openDay_loadError,
                    style: context.textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
            if (selectedId != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  vertical: MqSpacing.space2,
                  horizontal: MqSpacing.space2,
                ),
                child: TextButton.icon(
                  icon: const Icon(Icons.close_rounded),
                  label: Text(l10n.openDay_clearSelection),
                  style: TextButton.styleFrom(
                    foregroundColor: dark
                        ? Colors.white.withValues(alpha: 0.85)
                        : MqColors.contentSecondary,
                  ),
                  onPressed: () async {
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .updateSelectedBachelorId(null);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BachelorList extends ConsumerWidget {
  const _BachelorList({required this.data, required this.selectedId});

  final OpenDayData data;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group bachelors by study area for fast visual scanning.
    final byArea = <String, List<OpenDayBachelor>>{};
    for (final b in data.bachelors) {
      byArea.putIfAbsent(b.studyAreaId, () => <OpenDayBachelor>[]).add(b);
    }

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: [
        for (final area in data.studyAreas)
          if (byArea[area.id] != null)
            _AreaSection(
              area: area,
              bachelors: byArea[area.id]!,
              selectedId: selectedId,
              onSelect: (b) async {
                await ref
                    .read(settingsControllerProvider.notifier)
                    .updateSelectedBachelorId(b.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
      ],
    );
  }
}

class _AreaSection extends StatelessWidget {
  const _AreaSection({
    required this.area,
    required this.bachelors,
    required this.selectedId,
    required this.onSelect,
  });

  final OpenDayStudyArea area;
  final List<OpenDayBachelor> bachelors;
  final String? selectedId;
  final void Function(OpenDayBachelor) onSelect;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            MqSpacing.space2,
            MqSpacing.space3,
            MqSpacing.space2,
            MqSpacing.space1,
          ),
          child: Text(
            area.name.toUpperCase(),
            style: context.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: dark ? MqColors.charcoal800 : MqColors.red,
            ),
          ),
        ),
        for (final b in bachelors)
          Semantics(
            button: true,
            selected: b.id == selectedId,
            label: b.name,
            child: ListTile(
              dense: true,
              title: Text(
                b.name,
                style: context.textTheme.bodyLarge?.copyWith(
                  fontWeight: b.id == selectedId
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: b.id == selectedId
                      ? (dark ? MqColors.charcoal800 : MqColors.red)
                      : (dark ? Colors.white : MqColors.contentPrimary),
                ),
              ),
              trailing: b.id == selectedId
                  ? Icon(
                      Icons.check_rounded,
                      color: dark ? MqColors.charcoal800 : MqColors.red,
                      size: 20,
                    )
                  : null,
              onTap: () => onSelect(b),
            ),
          ),
      ],
    );
  }
}
