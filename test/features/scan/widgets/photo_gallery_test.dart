import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/features/scan/presentation/widgets/photo_gallery.dart';

void main() {
  testWidgets('renders one page per photo with dots', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PhotoGallery(
          photos: [
            'assets/photos/_placeholder.jpg',
            'assets/photos/_placeholder.jpg',
          ],
          fallbackAsset: 'assets/images/placeholder_hero.png',
        ),
      ),
    ));
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-dot-1')), findsOneWidget);
  });

  testWidgets('falls back to fallbackAsset when photos empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PhotoGallery(
          photos: [],
          fallbackAsset: 'assets/images/placeholder_hero.png',
        ),
      ),
    ));
    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery-dot-0')), findsNothing);
  });
}
