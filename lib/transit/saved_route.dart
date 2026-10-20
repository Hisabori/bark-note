import 'planner.dart';

class SavedRoute {
  const SavedRoute(
    this.name,
    this.station,
    this.destination,
    this.train,
    this.minutes,
    this.hour,
    this.minute,
  );
  final String name, station, destination, train;
  final List<int> minutes;
  final int hour, minute;

  static SavedRoute? parse(dynamic value) {
    if (value is! Map) return null;
    final times = value['minutes'];
    final hour = value['hour'], minute = value['minute'];
    if (times is! List ||
        times.length != 5 ||
        times.any((v) => v is! int || v < 0 || v > 240) ||
        times[1] == 0 ||
        hour is! int ||
        hour < 0 ||
        hour > 23 ||
        minute is! int ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    for (final key in ['name', 'station', 'destination', 'train']) {
      if (value[key] is! String) return null;
    }
    if ((value['name'] as String).trim().isEmpty ||
        (value['station'] as String).trim().isEmpty ||
        (value['destination'] as String).trim().isEmpty) {
      return null;
    }
    return SavedRoute(
      value['name'],
      value['station'],
      value['destination'],
      value['train'],
      times.cast<int>(),
      hour,
      minute,
    );
  }

  DateTime nextDeadline(DateTime now) {
    final clock = seoulClock(now);
    final today = seoulInstant(
      clock.year,
      clock.month,
      clock.day,
      hour,
      minute,
    );
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'station': station,
    'destination': destination,
    'train': train,
    'minutes': minutes,
    'hour': hour,
    'minute': minute,
  };
}
