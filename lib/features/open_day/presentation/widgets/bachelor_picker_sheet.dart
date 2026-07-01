import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/features/open_day/data/open_day_providers.dart';
import 'package:mq_journey/features/open_day/domain/entities/open_day_data.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/extensions/context_extensions.dart';
import 'package:mq_journey/shared/widgets/mq_bottom_sheet.dart';

/// Lightweight, non-blocking bachelor picker. Surfaces as a bottom sheet
/// so it never feels like an account-setup wall — the user can dismiss
/// and the app keeps working without a selection.
///
/// The list is sorted alphabetically by displayed title and filterable via
/// a search field — at 39 degrees, faculty grouping no longer scanned well,
/// so a flat, searchable list replaced it. Tapping a row immediately commits
/// the choice (no "Save" button) — this is a preference, not a form
/// submission.
class BachelorPickerSheet extends ConsumerWidget {
  const BachelorPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const BachelorPickerSheet(),
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

    return MqBottomSheet(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
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

class _BachelorList extends ConsumerStatefulWidget {
  const _BachelorList({required this.data, required this.selectedId});

  final OpenDayData data;
  final String? selectedId;

  @override
  ConsumerState<_BachelorList> createState() => _BachelorListState();
}

class _BachelorListState extends ConsumerState<_BachelorList> {
  late final List<OpenDayBachelor> _sorted = [...widget.data.bachelors]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _sorted
        : _sorted.where((b) => b.name.toLowerCase().contains(query)).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            MqSpacing.space2,
            0,
            MqSpacing.space2,
            MqSpacing.space3,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            style: context.textTheme.bodyMedium?.copyWith(
              color: dark ? Colors.white : MqColors.contentPrimary,
            ),
            decoration: InputDecoration(
              hintText: l10n.openDay_searchBachelorHint,
              hintStyle: context.textTheme.bodyMedium?.copyWith(
                color: dark
                    ? Colors.white.withValues(alpha: 0.55)
                    : MqColors.contentSecondary,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: dark
                    ? Colors.white.withValues(alpha: 0.55)
                    : MqColors.contentSecondary,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: dark
                          ? Colors.white.withValues(alpha: 0.65)
                          : MqColors.contentSecondary,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : MqColors.charcoal800.withValues(alpha: 0.05),
              contentPadding: const EdgeInsetsDirectional.symmetric(
                vertical: MqSpacing.space3,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MqSpacing.radiusLg),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Flexible(
          child: filtered.isEmpty
              ? _NoMatchState(l10n: l10n, dark: dark)
              : ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final b in filtered)
                      _BachelorRow(
                        bachelor: b,
                        selectedId: widget.selectedId,
                        onSelect: (selected) async {
                          await ref
                              .read(settingsControllerProvider.notifier)
                              .updateSelectedBachelorId(selected.id);
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _NoMatchState extends StatelessWidget {
  const _NoMatchState({required this.l10n, required this.dark});

  final AppLocalizations l10n;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: MqSpacing.space6,
        horizontal: MqSpacing.space4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 28,
            color: dark
                ? Colors.white.withValues(alpha: 0.45)
                : MqColors.contentSecondary,
          ),
          const SizedBox(height: MqSpacing.space2),
          Text(
            l10n.openDay_noBachelorMatch,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: dark ? Colors.white : MqColors.contentPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.openDay_noBachelorMatchHint,
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: dark
                  ? Colors.white.withValues(alpha: 0.65)
                  : MqColors.contentSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BachelorRow extends StatelessWidget {
  const _BachelorRow({
    required this.bachelor,
    required this.selectedId,
    required this.onSelect,
  });

  final OpenDayBachelor bachelor;
  final String? selectedId;
  final void Function(OpenDayBachelor) onSelect;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDarkMode;
    final selected = bachelor.id == selectedId;
    return Semantics(
      button: true,
      selected: selected,
      label: bachelor.name,
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          dense: true,
          title: Text(
            bachelor.name,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? (dark ? MqColors.charcoal800 : MqColors.red)
                  : (dark ? Colors.white : MqColors.contentPrimary),
            ),
          ),
          trailing: selected
              ? Icon(
                  Icons.check_rounded,
                  color: dark ? MqColors.charcoal800 : MqColors.red,
                  size: 20,
                )
              : null,
          onTap: () => onSelect(bachelor),
        ),
      ),
    );
  }
}
