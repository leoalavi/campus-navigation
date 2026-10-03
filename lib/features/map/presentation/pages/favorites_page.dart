import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/app/l10n/generated/app_localizations.dart';
import 'package:mq_navigation/app/theme/mq_colors.dart';
import 'package:mq_navigation/app/theme/mq_spacing.dart';
import 'package:mq_navigation/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:mq_navigation/features/map/presentation/widgets/building_actions_sheet.dart';
import 'package:mq_navigation/shared/extensions/context_extensions.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesControllerProvider.notifier).load();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(favoritesControllerProvider.notifier).refresh();
  }

  Future<bool> _confirmRemove(String buildingName) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.favoritesDeleteConfirm),
        content: Text(l10n.favoritesDeleteConfirmBody(buildingName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.favoritesDeleteCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: MqColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.favoritesDeleteYes),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Opens a dialog allowing the user to add or amend the freeform note
  /// attached to a favourited building. This is the **Update** half of CRUD
  /// — it round-trips through the controller, which calls Supabase and
  /// reconciles state on success.
  ///
  /// The dialog is cancellable; only an explicit Save commits the change.
  /// Empty input is allowed — it clears the note server-side.
  Future<void> _editNote({
    required String id,
    required String buildingName,
    required String? existingNote,
  }) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => _EditNoteDialog(
        buildingName: buildingName,
        initialNote: existingNote,
      ),
    );

    if (result == null) return; // Cancelled.
    if (!mounted) return;

    await ref
        .read(favoritesControllerProvider.notifier)
        .updateNote(id: id, note: result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(favoritesControllerProvider);
    final dark = context.isDarkMode;

    return Scaffold(
      backgroundColor: dark ? MqColors.charcoal800 : Colors.white,
      appBar: AppBar(
        title: Text(l10n.favoritesTitle),
        backgroundColor: dark ? MqColors.charcoal800 : Colors.white,
        foregroundColor: dark ? Colors.white : MqColors.contentPrimary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (dark)
            PositionedDirectional(
              top: -80,
              start: 0,
              end: 0,
              height: 380,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1.2),
                      radius: 1.1,
                      colors: [
                        MqColors.red.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          if (state.isLoading && state.favorites.isEmpty)
            const Center(child: CircularProgressIndicator(color: MqColors.red))
          else if (state.error != null && state.favorites.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(MqSpacing.space6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: MqColors.slate500,
                    ),
                    const SizedBox(height: MqSpacing.space4),
                    Text(
                      state.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dark ? Colors.white : MqColors.contentPrimary,
                      ),
                    ),
                    const SizedBox(height: MqSpacing.space4),
                    FilledButton.icon(
                      onPressed: _onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            )
          else if (state.favorites.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(MqSpacing.space8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 72,
                      color: dark
                          ? Colors.white.withValues(alpha: 0.3)
                          : MqColors.slate400,
                    ),
                    const SizedBox(height: MqSpacing.space6),
                    Text(
                      l10n.favoritesEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: dark ? Colors.white : MqColors.contentSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            RefreshIndicator(
              onRefresh: _onRefresh,
              color: MqColors.red,
              child: ListView.builder(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  MqSpacing.space4,
                  MqSpacing.space2,
                  MqSpacing.space4,
                  MqSpacing.space12,
                ),
                itemCount: state.favorites.length,
                itemBuilder: (context, index) {
                  final fav = state.favorites[index];
                  return Dismissible(
                    key: ValueKey(fav.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: MqSpacing.space5),
                      color: MqColors.red,
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    confirmDismiss: (_) => _confirmRemove(fav.buildingName),
                    onDismissed: (_) {
                      unawaited(
                        ref
                            .read(favoritesControllerProvider.notifier)
                            .remove(fav.id),
                      );
                    },
                    child: Card(
                      color: dark
                          ? MqColors.charcoal800.withValues(alpha: 0.94)
                          : Colors.white,
                      margin: const EdgeInsets.symmetric(
                        vertical: MqSpacing.space1,
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: MqColors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.business_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          fav.buildingName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: dark
                                ? Colors.white
                                : MqColors.contentPrimary,
                          ),
                        ),
                        // Subtitle prefers the user's note (the editable
                        // field) and falls back to the stable building
                        // code so each row is always identifiable.
                        subtitle: Text(
                          (fav.note != null && fav.note!.trim().isNotEmpty)
                              ? fav.note!
                              : fav.buildingId,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontStyle:
                                (fav.note != null &&
                                    fav.note!.trim().isNotEmpty)
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: dark
                                ? Colors.white.withValues(alpha: 0.6)
                                : MqColors.contentSecondary,
                          ),
                        ),
                        // Trailing row: red directions icon + kebab menu.
                        //
                        // • Directions icon (Icons.directions_rounded in red)
                        //   — same pattern as Open Day event tiles. Opens
                        //   BuildingActionsSheet so the user can choose
                        //   Campus Map or Google Maps. Does NOT immediately
                        //   navigate — the user picks first.
                        //
                        // • Kebab menu — note (Add/Edit) and Remove only.
                        //   "Add note" when the building has no saved note,
                        //   "Edit note" when one already exists. "Remove"
                        //   (not "Yes, remove") matches standard UX copy.
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l10n.openDay_directionsTo(
                                fav.buildingName,
                              ),
                              icon: Icon(
                                Icons.directions_rounded,
                                color: dark ? MqColors.brightRed : MqColors.red,
                              ),
                              onPressed: () => BuildingActionsSheet.show(
                                context,
                                buildingId: fav.buildingId,
                                buildingName: fav.buildingName,
                              ),
                            ),
                            PopupMenuButton<_FavoriteRowAction>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: dark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : MqColors.contentSecondary,
                              ),
                              onSelected: (action) async {
                                switch (action) {
                                  case _FavoriteRowAction.edit:
                                    await _editNote(
                                      id: fav.id,
                                      buildingName: fav.buildingName,
                                      existingNote: fav.note,
                                    );
                                  case _FavoriteRowAction.remove:
                                    final confirmed = await _confirmRemove(
                                      fav.buildingName,
                                    );
                                    if (confirmed && context.mounted) {
                                      await ref
                                          .read(
                                            favoritesControllerProvider
                                                .notifier,
                                          )
                                          .remove(fav.id);
                                    }
                                }
                              },
                              itemBuilder: (ctx) {
                                final hasNote =
                                    fav.note?.trim().isNotEmpty == true;
                                return [
                                  PopupMenuItem(
                                    value: _FavoriteRowAction.edit,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.edit_note_rounded,
                                          color: MqColors.red,
                                        ),
                                        const SizedBox(width: 12),
                                        // Label reflects whether a note
                                        // already exists so the user
                                        // always sees the right verb.
                                        Text(
                                          hasNote
                                              ? l10n.favoritesEditNote
                                              : l10n.favoritesAddNote,
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _FavoriteRowAction.remove,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.delete_outline_rounded,
                                          color: MqColors.red,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(l10n.favoritesRemove),
                                      ],
                                    ),
                                  ),
                                ];
                              },
                            ),
                          ],
                        ),
                        // Row tap is intentionally disabled — navigation is
                        // triggered exclusively through the red directions
                        // icon so the user consciously picks their renderer.
                        onTap: null,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Discrete actions the favourite-row kebab menu can dispatch.
///
/// Modelled as an enum (rather than free strings) so the `onSelected`
/// switch is exhaustively checked by the analyzer — adding a new action
/// becomes a compile-time error if a handler is missed.
enum _FavoriteRowAction { edit, remove }

/// Standalone stateful dialog that owns its own [TextEditingController].
///
/// Pulled out of `_editNote` so the controller's lifecycle is tied to the
/// widget's `State.dispose()` — never the outer page. Returning the
/// trimmed note (or `null` on cancel) through `Navigator.pop` is the only
/// communication surface, keeping this widget reusable and testable.
class _EditNoteDialog extends StatefulWidget {
  const _EditNoteDialog({
    required this.buildingName,
    required this.initialNote,
  });

  final String buildingName;
  final String? initialNote;

  @override
  State<_EditNoteDialog> createState() => _EditNoteDialogState();
}

class _EditNoteDialogState extends State<_EditNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = context.isDarkMode;
    return AlertDialog(
      backgroundColor: dark ? MqColors.charcoal800 : Colors.white,
      title: Text(
        widget.buildingName,
        style: TextStyle(
          color: dark ? Colors.white : MqColors.contentPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        maxLength: 280,
        decoration: InputDecoration(
          hintText: l10n.favoritesNoteHint,
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: MqColors.red, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.favoritesDeleteCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: MqColors.red),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(l10n.favoritesSaveNote),
        ),
      ],
    );
  }
}
