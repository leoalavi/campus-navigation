import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mq_journey/app/l10n/generated/app_localizations.dart';
import 'package:mq_journey/features/notifications/domain/entities/app_notification.dart';
import 'package:mq_journey/features/notifications/presentation/widgets/notification_tile.dart';

Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

AppNotification _notification({required bool isRead}) {
  return AppNotification(
    id: '1',
    type: NotificationType.event,
    title: 'Open Day is tomorrow',
    body: 'Don\'t forget to bring your student ID.',
    createdAt: DateTime(2026, 8, 21, 10),
    isRead: isRead,
  );
}

void main() {
  testWidgets('shows the "mark as read" action for unread notifications', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      _app(
        NotificationTile(
          notification: _notification(isRead: false),
          onTap: () {},
          onMarkRead: () {},
          onDelete: () {},
        ),
      ),
    );

    expect(find.text(l10n.markAsRead), findsOneWidget);
    expect(find.text(l10n.delete), findsOneWidget);
  });

  testWidgets('hides the "mark as read" action once already read', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      _app(
        NotificationTile(
          notification: _notification(isRead: true),
          onTap: () {},
          onMarkRead: () {},
          onDelete: () {},
        ),
      ),
    );

    expect(find.text(l10n.markAsRead), findsNothing);
    expect(find.text(l10n.delete), findsOneWidget);
  });

  testWidgets('tapping the tile invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(
        NotificationTile(
          notification: _notification(isRead: false),
          onTap: () => tapped = true,
          onMarkRead: () {},
          onDelete: () {},
        ),
      ),
    );

    await tester.tap(find.text('Open Day is tomorrow'));
    expect(tapped, isTrue);
  });

  testWidgets('tapping delete invokes onDelete', (tester) async {
    var deleted = false;
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      _app(
        NotificationTile(
          notification: _notification(isRead: false),
          onTap: () {},
          onMarkRead: () {},
          onDelete: () => deleted = true,
        ),
      ),
    );

    await tester.tap(find.text(l10n.delete));
    expect(deleted, isTrue);
  });
}
