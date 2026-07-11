import 'package:flutter/material.dart';
import 'package:mq_journey/features/scan/domain/contracts/visited_state.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';

class CardVisitBadge extends StatelessWidget {
  const CardVisitBadge({super.key, required this.state});
  final VisitedState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!state.visited) return const SizedBox.shrink();
    return Chip(
      avatar: const Icon(Icons.star, size: 18, color: Colors.amber),
      label: Text(
        state.rewardEarned ? l10n.scanBadgeEarned : l10n.scanBadgeVisited,
      ),
      backgroundColor: Colors.amber[50],
    );
  }
}
