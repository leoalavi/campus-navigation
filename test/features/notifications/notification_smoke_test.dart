import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mq_navigation/features/notifications/data/datasources/fcm_service.dart';
import 'package:mq_navigation/features/notifications/data/datasources/local_notifications_service.dart';
import 'package:mq_navigation/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:mq_navigation/features/notifications/domain/entities/app_notification.dart';
import 'package:mq_navigation/features/notifications/domain/entities/notification_preferences.dart';
import 'package:mq_navigation/features/notifications/domain/services/notification_scheduler.dart';
import 'package:mq_navigation/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:mq_navigation/features/notifications/domain/entities/reminder_request.dart';
import 'package:mq_navigation/shared/models/user_preferences.dart';
import 'package:mq_navigation/features/settings/data/repositories/settings_repository.dart';
import 'package:mq_navigation/core/network/connectivity_service.dart';
import 'package:mq_navigation/features/auth/data/repositories/auth_repository.dart';
import 'package:mq_navigation/features/auth/presentation/controllers/auth_controller.dart';

class MockLocalNotificationsService extends Mock
    implements LocalNotificationsService {}

class MockFcmService extends Mock implements FcmService {}

class MockNotificationRepository extends Mock
    implements NotificationRepositoryImpl {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockLocalNotificationsService mockLocalNotifications;
  late MockFcmService mockFcm;
  late MockNotificationRepository mockRepo;
  late MockSettingsRepository mockSettingsRepo;
  late MockAuthRepository mockAuthRepo;

  setUpAll(() {
    registerFallbackValue(
      const NotificationPreference(
        type: NotificationType.studyPrompt,
        enabled: true,
      ),
    );
    registerFallbackValue(const UserPreferences());
    registerFallbackValue(
      ReminderRequest(
        notificationId: 0,
        stableId: '',
        type: NotificationType.system,
        title: '',
        body: '',
        scheduledFor: DateTime.now(),
      ),
    );
  });

  setUp(() {
    mockLocalNotifications = MockLocalNotificationsService();
    mockFcm = MockFcmService();
    mockRepo = MockNotificationRepository();
    mockSettingsRepo = MockSettingsRepository();
    mockAuthRepo = MockAuthRepository();

    when(() => mockAuthRepo.userId).thenReturn(null);
    when(() => mockAuthRepo.isAuthenticated).thenReturn(false);

    when(
      () => mockSettingsRepo.loadPreferences(),
    ).thenAnswer((_) async => const UserPreferences());

    // Setup default mock behaviors
    when(
      () => mockLocalNotifications.initialize(
        onOpenLink: any(named: 'onOpenLink'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockLocalNotifications.notificationIdForStableId(any()),
    ).thenReturn(101);
    when(
      () => mockLocalNotifications.cancelManagedNotificationsExcept(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockLocalNotifications.scheduleReminder(any()),
    ).thenAnswer((_) async {});

    when(
      () => mockFcm.initialize(onOpenLink: any(named: 'onOpenLink')),
    ).thenAnswer((_) async {});
    when(
      () => mockFcm.getPermissionStatus(),
    ).thenAnswer((_) async => NotificationPermissionStatus.granted);
    when(() => mockFcm.syncToken(any())).thenAnswer((_) async {});

    when(
      () => mockRepo.fetchPreferences(any()),
    ).thenAnswer((_) async => NotificationPreference.defaults());
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        localNotificationsServiceProvider.overrideWithValue(
          mockLocalNotifications,
        ),
        fcmServiceProvider.overrideWithValue(mockFcm),
        notificationRepositoryProvider.overrideWithValue(mockRepo),
        settingsRepositoryProvider.overrideWithValue(mockSettingsRepo),
        connectivityStatusProvider.overrideWith(
          (ref) => Stream.value(ConnectivityStatus.online),
        ),
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
      ],
    );
  }

  group('Notifications System End-to-End Audit & Smoke Test', () {
    test('initializes and syncs preferences and tokens on startup', () async {
      final container = makeContainer();
      addTearDown(() => container.dispose());

      // Read controller to trigger build lifecycle
      final state = await container.read(
        notificationsControllerProvider.future,
      );

      // Verify that FCM and Local Notifications services are initialized
      verify(
        () => mockLocalNotifications.initialize(
          onOpenLink: any(named: 'onOpenLink'),
        ),
      ).called(1);
      verify(
        () => mockFcm.initialize(onOpenLink: any(named: 'onOpenLink')),
      ).called(1);

      // Verify permission statuses were retrieved and correct default preferences are populated
      expect(state.permissionStatus, NotificationPermissionStatus.granted);
      expect(state.preferences, hasLength(NotificationType.values.length));
    });

    test('reconciles local reminders based on quiet hours setup', () {
      final scheduler = NotificationScheduler(mockLocalNotifications);
      final now = DateTime(2026, 3, 11, 22); // 10 PM

      // Configure quiet hours (10 PM to 7 AM)
      final userPrefs = const UserPreferences().copyWith(
        quietHoursEnabled: true,
        quietHoursStart: '22:00',
        quietHoursEnd: '07:00',
      );

      final requests = scheduler.buildRequests(
        preferences:
            NotificationPreference.defaults(), // Defaults scheduled Hour = 9 AM
        userPreferences: userPrefs,
        now: now,
      );

      // Default study prompt scheduled at 9 AM is OUTSIDE quiet hours (10 PM to 7 AM).
      // Since 'now' is 10 PM (22:00) on March 11th, today's 9 AM is in the past,
      // so it is scheduled for tomorrow (March 12th) at 9 AM.
      expect(requests, hasLength(1));
      expect(requests.first.scheduledFor, DateTime(2026, 3, 12, 9));
    });

    test('shifts scheduled reminder into end of quiet hours if overlap exists', () {
      final scheduler = NotificationScheduler(mockLocalNotifications);
      final now = DateTime(2026, 3, 11, 8); // 8 AM

      // Configure quiet hours covering the default scheduled hour (9 AM) -> quiet hours 8 AM to 10 AM
      final userPrefs = const UserPreferences().copyWith(
        quietHoursEnabled: true,
        quietHoursStart: '08:00',
        quietHoursEnd: '10:00',
      );

      final requests = scheduler.buildRequests(
        preferences: NotificationPreference.defaults(),
        userPreferences: userPrefs,
        now: now,
      );

      // Default study prompt triggers at 9 AM which is INSIDE quiet hours (8 AM to 10 AM).
      // It should shift to the end of quiet hours (10:00 AM).
      expect(requests, hasLength(1));
      expect(requests.first.scheduledFor, DateTime(2026, 3, 11, 10));
    });
  });
}
