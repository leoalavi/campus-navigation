import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mq_navigation/app/l10n/generated/app_localizations.dart';
import 'package:mq_navigation/app/theme/mq_colors.dart';
import 'package:mq_navigation/app/theme/mq_spacing.dart';
import 'package:mq_navigation/shared/widgets/mq_bottom_sheet.dart';

class BuildingActionsSheet extends StatelessWidget {
  const BuildingActionsSheet({
    super.key,
    required this.buildingId,
    required this.buildingName,
  });

  final String buildingId;
  final String buildingName;

  static Future<void> show(
    BuildContext context, {
    required String buildingId,
    required String buildingName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BuildingActionsSheet(
        buildingId: buildingId,
        buildingName: buildingName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MqBottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            buildingName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : MqColors.contentPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MqSpacing.space4),
          // Single location action: show the place on the Campus Map. The
          // generic "Navigate" (route preview) flow was removed — for Open Day
          // we only want to surface the location, not start turn-by-turn nav.
          _ActionButton(
            icon: Icons.map_outlined,
            label: l10n.navigateOnCampus,
            onTap: () {
              Navigator.pop(context);
              context.goNamed('map', queryParameters: {'building': buildingId});
            },
          ),
          const SizedBox(height: MqSpacing.space3),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: MqSpacing.space2),
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 20),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : MqColors.contentPrimary,
              side: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : MqColors.charcoal800.withValues(alpha: 0.12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MqSpacing.radiusMd),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
