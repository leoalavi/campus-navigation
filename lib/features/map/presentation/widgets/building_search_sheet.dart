import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/app/theme/mq_spacing.dart';
import 'package:mq_journey/core/utils/haptics.dart';
import 'package:mq_journey/features/map/domain/entities/building.dart';
import 'package:mq_journey/features/map/presentation/controllers/map_controller.dart';
import 'package:mq_journey/features/settings/presentation/controllers/settings_controller.dart';
import 'package:mq_journey/shared/extensions/context_extensions.dart';
import 'package:mq_journey/shared/widgets/campus_text.dart';

class BuildingSearchSheet extends ConsumerStatefulWidget {
  const BuildingSearchSheet({super.key});

  @override
  ConsumerState<BuildingSearchSheet> createState() =>
      _BuildingSearchSheetState();
}

class _BuildingSearchSheetState extends ConsumerState<BuildingSearchSheet> {
  late final TextEditingController _controller;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(mapControllerProvider).value?.searchQuery ?? '',
    );
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(mapControllerProvider.notifier).updateSearchQuery(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.isDarkMode;
    final state = ref.watch(mapControllerProvider).value;
    final results = state?.searchResults ?? const <Building>[];
    final query = _controller.text.trim();

    // A single, full-height search surface (canonical Maps "search page"
    // pattern). It fills the sheet region so the map's own search pill can
    // never remain visible behind a half-open panel — no duplicate search
    // bars, and no dark scrim showing through over the map.
    return Material(
      color: isDark ? MqColors.charcoal900 : Colors.white,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(MqSpacing.space6),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle — signals the sheet can be pulled down to dismiss.
            Padding(
              padding: const EdgeInsets.only(top: MqSpacing.space3),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.24)
                      : MqColors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MqSpacing.space4,
                MqSpacing.space3,
                MqSpacing.space2,
                MqSpacing.space2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        color: isDark ? Colors.white : MqColors.contentPrimary,
                      ),
                      cursorColor: isDark ? Colors.white : MqColors.red,
                      decoration: InputDecoration(
                        hintText: l10n.searchBuildingsPlaceholder,
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : MqColors.contentTertiary,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? MqColors.charcoal800
                            : MqColors.charcoal800.withValues(alpha: 0.05),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.6)
                              : MqColors.contentTertiary,
                        ),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 20,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : MqColors.contentTertiary,
                                ),
                                tooltip: l10n.clear,
                                onPressed: () {
                                  _controller.clear();
                                  _onSearchChanged('');
                                  setState(() {});
                                },
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            MqSpacing.radiusFull,
                          ),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        _onSearchChanged(value);
                        setState(() {});
                      },
                      onSubmitted: (_) => _searchFocusNode.unfocus(),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _searchFocusNode.unfocus();
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      l10n.back,
                      style: TextStyle(
                        color: isDark ? Colors.white : MqColors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty && query.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MqSpacing.space8,
                        ),
                        child: Text(
                          l10n.noBuildingsFound(query),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : MqColors.contentTertiary,
                              ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: MqSpacing.space4),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final building = results[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: MqColors.red,
                          ),
                          title: CampusText(
                            building.name,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : MqColors.contentPrimary,
                            ),
                          ),
                          subtitle: CampusText(
                            building.code,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : MqColors.contentSecondary,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : MqColors.contentTertiary,
                          ),
                          onTap: () {
                            final haptics =
                                ref
                                    .read(settingsControllerProvider)
                                    .value
                                    ?.hapticsEnabled ??
                                true;
                            MqHaptics.selection(haptics);
                            _searchFocusNode.unfocus();
                            Navigator.of(context).pop(building);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
