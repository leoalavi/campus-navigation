import 'package:flutter/material.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/app/theme/mq_colors.dart';
import 'package:mq_journey/features/scan/domain/models/indoor_manifest.dart';
import 'package:mq_journey/shared/widgets/glass_surface.dart';

/// Fixed chip width so scene scrolling is index-based (reaches chips a lazy
/// list never built — GlobalKey/ensureVisible cannot).
const double kSceneChipExtent = 165;
const double _chipGap = 9;

/// Height to reserve above the floating tab-bar island so the rail clears it
/// when the viewer is shown *inside* the shell (the `indoorPreview` route).
/// Measured, not guessed: the `LiquidTabBar` is 66px tall (its `height`
/// default) plus the island's 12px bottom padding in `AppShell`. The rail's
/// own bottom `SafeArea` still handles the device inset on top of this; a
/// deterministic layout test (`indoor_preview_clearance_test.dart`) asserts
/// the rail clears the island. The top-level `locationAr` route has no tab bar
/// and passes 0.
const double kTabBarIslandClearance = 78;

/// A floating, collapsible glass rail of indoor scene chips, anchored to the
/// bottom-left. Controlled: [selectedSceneId] in, [onSceneSelected] out.
///
/// Tapping the leading round button collapses the rail to just that button (a
/// circle on the left); tapping the circle expands it again. Frost-forced (no
/// shader) — it floats over a platform-view panorama a shader cannot sample.
class SceneRail extends StatefulWidget {
  const SceneRail({
    super.key,
    required this.manifest,
    required this.selectedSceneId,
    required this.onSceneSelected,
  });

  final IndoorManifest manifest;
  final String? selectedSceneId;
  final ValueChanged<String> onSceneSelected;

  @override
  State<SceneRail> createState() => _SceneRailState();
}

class _SceneRailState extends State<SceneRail> {
  final ScrollController _controller = ScrollController();
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToSelected(animate: false),
    );
  }

  @override
  void didUpdateWidget(covariant SceneRail old) {
    super.didUpdateWidget(old);
    final selectionChanged = old.selectedSceneId != widget.selectedSceneId;
    final manifestChanged =
        old.manifest.nodes.length != widget.manifest.nodes.length;
    if (selectionChanged || manifestChanged) {
      final animate = manifestChanged
          ? false
          : !MediaQuery.disableAnimationsOf(context);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToSelected(animate: animate),
      );
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      // The list is rebuilt when re-expanding — re-centre on the selection.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToSelected(animate: false),
      );
    }
  }

  void _scrollToSelected({required bool animate}) {
    if (!mounted || !_expanded || !_controller.hasClients) return;
    final index = widget.manifest.nodes.indexWhere(
      (n) => n.id == widget.selectedSceneId,
    );
    if (index < 0) return;
    final target = (index * (kSceneChipExtent + _chipGap)).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.manifest.isEmpty) return const SizedBox.shrink();

    // Anchored bottom-left, snug above the tab bar. AnimatedSize morphs the
    // box between the wide pill and the collapsed circle, growing from the
    // bottom-left corner.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 12,
          end: 12,
          bottom: 8,
        ),
        child: Align(
          alignment: AlignmentDirectional.bottomStart,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: AlignmentDirectional.bottomStart,
            child: _expanded ? _buildExpanded(l10n) : _buildCollapsed(l10n),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsed(AppLocalizations l10n) {
    return _RailRoundButton(
      icon: Icons.grid_view_rounded,
      label: l10n.indoorScenesLabel,
      glassBacking: true,
      onTap: _toggle,
    );
  }

  Widget _buildExpanded(AppLocalizations l10n) {
    final chipHeight =
        (MediaQuery.textScalerOf(context).scale(13) * 1.3 +
                MediaQuery.textScalerOf(context).scale(10.5) * 1.3 +
                24)
            .clamp(52.0, 140.0);
    return GlassSurface(
      variant: GlassVariant.control,
      allowShader: false, // platform-view overlay: frost, never shader
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RailRoundButton(
              icon: Icons.close_rounded,
              label: MaterialLocalizations.of(context).closeButtonLabel,
              glassBacking: false,
              onTap: _toggle,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: SizedBox(
                height: chipHeight,
                child: ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: widget.manifest.nodes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: _chipGap),
                  itemBuilder: (context, i) {
                    final node = widget.manifest.nodes[i];
                    return _SceneChip(
                      name: node.description.isNotEmpty
                          ? node.description
                          : node.id,
                      subtitle: node.neighbours.isNotEmpty
                          ? l10n.indoorConnections(node.neighbours.length)
                          : null,
                      selected: node.id == widget.selectedSceneId,
                      onTap: () => widget.onSceneSelected(node.id),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round red control. When [glassBacking] is true it sits inside a glass
/// disc (the collapsed state, floating over the panorama); otherwise it's the
/// bare red core (already on the expanded glass pill).
class _RailRoundButton extends StatelessWidget {
  const _RailRoundButton({
    required this.icon,
    required this.label,
    required this.glassBacking,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool glassBacking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Brand-red core keeps the icon legible over any backdrop and gives a
    // 44px+ tap target (56 with the glass disc).
    final core = Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [MqColors.red, MqColors.deepRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );

    final Widget button = glassBacking
        ? GlassSurface(
            variant: GlassVariant.control,
            allowShader: false,
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(6),
            child: core,
          )
        : core;

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: GestureDetector(onTap: onTap, child: button),
    );
  }
}

class _SceneChip extends StatelessWidget {
  const _SceneChip({
    required this.name,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // One merged, actionable node per chip — no duplicate text node.
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      label: subtitle == null ? name : '$name, $subtitle',
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          // Bounded width so ellipsis actually triggers on long names.
          constraints: const BoxConstraints(
            minWidth: 92,
            maxWidth: kSceneChipExtent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            // Solid chips (dark / brand-red) carry their own contrast so white
            // labels stay legible over the translucent glass tray — the tray,
            // not the chip, is what reads as glass.
            gradient: selected
                ? const LinearGradient(
                    colors: [MqColors.red, MqColors.deepRed],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.black.withValues(alpha: 0.78),
            border: Border.all(
              color: Colors.white.withValues(alpha: selected ? 0.4 : 0.16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: selected ? 0.9 : 0.7),
                    fontSize: 10.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
