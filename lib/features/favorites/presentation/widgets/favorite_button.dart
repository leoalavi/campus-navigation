import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mq_navigation/app/theme/mq_colors.dart';
import 'package:mq_navigation/features/favorites/presentation/controllers/favorites_controller.dart';

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    super.key,
    required this.buildingId,
    required this.buildingName,
    this.size = 24,
  });

  final String buildingId;
  final String buildingName;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoritesControllerProvider);
    final isFav = state.favoritedBuildingIds.contains(buildingId);

    return IconButton(
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: isFav ? MqColors.brightRed : null,
        size: size,
      ),
      onPressed: () {
        ref
            .read(favoritesControllerProvider.notifier)
            .toggle(buildingId: buildingId, buildingName: buildingName);
      },
    );
  }
}
