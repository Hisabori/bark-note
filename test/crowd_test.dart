import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/transit/crowd_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'official complete crowd asset loads with scoped source values',
    () async {
      final data = await CrowdData.load();
      expect(data.asOf, '2026-06-30');
      expect(data.profiles.length, 1671);
      final rows = data
          .forStation('서울', '1호선')
          .where((p) => p.day == '평일' && p.direction == '상선')
          .toList();
      expect(rows.length, 1);
      expect(rows.single.slots[330], 8.8);
      expect(data.forStation('서울', '9호선'), isEmpty);
      expect(crowdDirection('상행'), '상선');
      expect(crowdStation('천호(풍납토성)'), '천호');
    },
  );
}
