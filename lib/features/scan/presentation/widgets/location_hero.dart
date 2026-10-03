import 'package:flutter/material.dart';
import 'package:mq_navigation/features/scan/domain/contracts/location_content.dart';

class LocationHero extends StatelessWidget {
  const LocationHero({super.key, required this.content});
  final LocationContent content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            content.heroImageAsset,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              height: 200,
              color: Colors.grey[300],
              child: const Center(child: Icon(Icons.image, size: 48)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(content.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          content.shortDescription,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
