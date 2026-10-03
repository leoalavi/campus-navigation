import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_navigation/core/network/session_guard.dart';
import 'package:mq_navigation/app/theme/mq_colors.dart';
import 'package:mq_navigation/features/auth/data/repositories/auth_repository.dart';
import 'package:mq_navigation/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mq_navigation/features/favorites/data/repositories/favorite_building_repository.dart';
import 'package:mq_navigation/features/favorites/domain/entities/favorite_building.dart';
import 'package:mq_navigation/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:mq_navigation/features/favorites/presentation/widgets/favorite_button.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockFavoriteBuildingRepository extends Mock
    implements FavoriteBuildingRepository {}

final _now = DateTime.now();

final _sampleFav = FavoriteBuilding(
  id: 'fav-1',
  userId: 'user-1',
  buildingId: 'BLD',
  buildingName: 'Library',
  note: null,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockFavoriteBuildingRepository mockFavRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    mockFavRepo = MockFavoriteBuildingRepository();
    when(() => mockAuthRepo.userId).thenReturn('user-1');
    // FavoritesController.build() now calls ref.listen(authControllerProvider),
    // which triggers AuthController.build() → mockAuthRepo.isAuthenticated.
    when(() => mockAuthRepo.isAuthenticated).thenReturn(false);
  });

  testWidgets('shows border heart when not favorited', (tester) async {
    when(
      () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
    ).thenAnswer((_) async => FavoritesResult.success([]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionGuardProvider.overrideWithValue(() async => true),
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
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
      () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
    ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionGuardProvider.overrideWithValue(() async => true),
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
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
      () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
    ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionGuardProvider.overrideWithValue(() async => true),
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
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
      () => mockFavRepo.fetchAll(userId: any(named: 'userId')),
    ).thenAnswer((_) async => FavoritesResult.success([_sampleFav]));
    when(
      () => mockFavRepo.findFavoriteId(
        userId: any(named: 'userId'),
        buildingId: any(named: 'buildingId'),
      ),
    ).thenAnswer((_) async => 'fav-1');
    when(
      () => mockFavRepo.remove(any()),
    ).thenAnswer((_) async => FavoritesResult.success(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionGuardProvider.overrideWithValue(() async => true),
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
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
