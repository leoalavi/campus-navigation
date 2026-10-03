import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

/// Centralised time formatting for Open Day events.
///
/// **Why this exists**
///   The Open Day dataset stores events with an explicit `+10:00` offset
///   (Sydney time). `DateTime.parse` preserves the *instant* but its
///   accessors (`hour`, `minute`, …) return values in the *device's*
///   local timezone. On a Sydney device that's a no-op, but on a UTC or
///   PST emulator, "13:00 +10:00" appears as "03:00" or "19:00 prev day"
///   — which surfaces as the AM/PM bug Open Day was reporting.
///
///   Pinning all formatting to `Australia/Sydney` removes that whole
///   class of bug and matches user expectation: Open Day is a Sydney
///   event; its schedule is a Sydney schedule.
///
/// **Initialisation**
///   `tz.initializeTimeZones()` is already called inside
///   `LocalNotificationsService.initialize()` at app start. We rely on
///   that being present; if a future entry-point bypasses it, callers
///   here will throw a clear `TimeZoneInitializationException` rather
///   than silently fall back to UTC.
class OpenDayTime {
  OpenDayTime._();

  /// IANA zone name. Open Day is held on the Wallumattagal Campus.
  static const String _zoneName = 'Australia/Sydney';

  /// Returns the canonical Sydney TZDateTime view of an event time.
  static tz.TZDateTime toSydney(DateTime instant) {
    return tz.TZDateTime.from(instant, tz.getLocation(_zoneName));
  }

  /// `'10:00 AM'` style. Used in event tiles and time-block headers.
  static String formatTimeOfDay(DateTime instant) {
    final sydney = toSydney(instant);
    return DateFormat('h:mm a').format(sydney);
  }

  /// `'10:00 AM – 10:30 AM'` style. Used for full event time ranges.
  static String formatTimeRange(DateTime start, DateTime end) {
    return '${formatTimeOfDay(start)} – ${formatTimeOfDay(end)}';
  }

  /// `'Saturday 15 August 2026'` style. Used for date headers.
  static String formatLongDate(DateTime instant) {
    final sydney = toSydney(instant);
    return DateFormat('EEEE d MMMM y').format(sydney);
  }

  /// `'8 Aug'` compact form — used in Home preview chips.
  static String formatShortDate(DateTime instant) {
    final sydney = toSydney(instant);
    return DateFormat('d MMM').format(sydney);
  }

  /// Hour bucket key for grouping events. Returns the Sydney-time hour
  /// number so events at 13:00 Sydney always group together regardless
  /// of device locale.
  static int sydneyHour(DateTime instant) => toSydney(instant).hour;
}
