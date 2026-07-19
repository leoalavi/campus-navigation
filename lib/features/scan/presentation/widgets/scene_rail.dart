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

/// A floating dark-glass rail of indoor scene chips. Controlled:
/// [selectedSceneId] in, [onSceneSelected] out. Frost-forced (no shader) — it
/// floats over a platform-view panorama that a shader cannot sample.
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

  void _scrollToSelected({required bool animate}) {
    if (!mounted || !_controller.hasClients) return;
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

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlassSurface(
          variant: GlassVariant.control,
          allowShader: false, // platform-view overlay: frost, never shader
          color: Colors.black, // dark tint keeps white chips legible
          borderRadius: BorderRadius.circular(24),
          // A dark scrim inside the rail so white text stays legible over ANY
          // backdrop — the panorama could be bright, and the frost alone isn't
          // opaque enough to guarantee contrast.
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 2,
                      bottom: 8,
                    ),
                    child: Text(
                      l10n.indoorScenesLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  // A horizontal list needs a bounded cross-axis (height); a
                  // bare minHeight leaves it unbounded. Reserve two text lines and
                  // let the height grow with the text scaler so large-text users
                  // never clip.
                  SizedBox(
                    height:
                        (MediaQuery.textScalerOf(context).scale(13) * 1.3 +
                                MediaQuery.textScalerOf(context).scale(10.5) *
                                    1.3 +
                                24)
                            .clamp(52.0, 140.0),
                    child: ListView.separated(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: widget.manifest.nodes.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: _chipGap),
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
                ],
              ),
            ),
          ),
        ),
      ),
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
            // Contrast-safe: white on red(#C6006F)→deepRed passes 4.5:1
            // (vivid #FF2D96 did not).
            gradient: selected
                ? const LinearGradient(
                    colors: [MqColors.red, MqColors.deepRed],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha: selected ? 0.4 : 0.14),
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
