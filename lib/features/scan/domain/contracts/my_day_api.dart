import 'package:campus_navigation/features/scan/domain/contracts/my_day_entry.dart';

abstract class MyDayApi {
  Future<void> addToDay(MyDayEntry entry);
}
