import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_navigation/app/theme/mq_colors.dart';
import 'package:mq_navigation/features/favorites/data/repositories/favorite_building_repository.dart';
import 'package:mq_navigation/features/favorites/domain/entities/favorite_building.dart';
import 'package:mq_navigation/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:mq_navigation/features/favorites/presentation/widgets/favorite_button.dart';

class MockFavoriteBuildingRepository extends Mock
    implements FavoriteBuildingRepository {}

final _now = DateTime.now();

final _sampleFav = FavoriteBuilding(
  id: 'fav-1',
  buildingId: 'BLD',
  buildingName: 'Library',
  note: null,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late MockFavoriteBuildingRepository mockFavRepo;

  setUp(() {
    mockFavRepo = MockFavoriteBuildingRepository();
  });

  testWidgets('shows border heart when not favorited', (tester) async {
    when(
      () => mockFavRepo.fetchAll(),
    ).thenAnswer((_) async => FavoritesResult.success([]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoriteBuildingRepositoryProvider.overrideWithValue(mockFavRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FavoriteButton(buildingId: 'BLD', buildingName: 'Library'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('shows filled heart when favorited', (tester) async {
    when(
      () => mockFavRepo.fetchAll(),
    ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoriteBuildingRepositoryProvider.overrideWithValue(mockFavRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FavoriteButton(buildingId: 'BLD', buildingName: 'Library'),
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FavoriteButton)),
    );

    await container.read(favoritesControllerProvider.notifier).load();
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('filled heart uses bright red color', (tester) async {
    when(
      () => mockFavRepo.fetchAll(),
    ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoriteBuildingRepositoryProvider.overrideWithValue(mockFavRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FavoriteButton(buildingId: 'BLD', buildingName: 'Library'),
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FavoriteButton)),
    );

    await container.read(favoritesControllerProvider.notifier).load();
    await tester.pump();

    final icon = tester.widget<Icon>(find.byIcon(Icons.favorite));
    expect(icon.color, MqColors.brightRed);
  });

  testWidgets('tap calls toggle', (tester) async {
    when(
      () => mockFavRepo.fetchAll(),
    ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));
    when(
      () => mockFavRepo.findFavoriteId(buildingId: any(named: 'buildingId')),
    ).thenAnswer((_) async => 'fav-1');
    when(
      () => mockFavRepo.remove(any()),
    ).thenAnswer((_) async => FavoritesResult.success(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoriteBuildingRepositoryProvider.overrideWithValue(mockFavRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FavoriteButton(buildingId: 'BLD', buildingName: 'Library'),
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FavoriteButton)),
    );

    await container.read(favoritesControllerProvider.notifier).load();
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();

    verify(() => mockFavRepo.remove('fav-1')).called(1);
  });
}
