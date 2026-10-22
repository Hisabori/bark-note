import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/transit/kakao_api.dart';
import 'package:bark_note/transit/place_book.dart';

void main() {
  const start = KakaoPlace('서울역', '서울', 126.972, 37.555);
  const end = KakaoPlace('강남역', '서울', 127.027, 37.498);
  const pair = PlacePair(start, end, name: '출근');
  test('history is deduplicated by direction and limited to ten', () {
    final book = PlaceBook();
    book.remember(pair);
    book.remember(pair);
    expect(book.recent.length, 1);
    book.remember(const PlacePair(end, start));
    expect(book.recent.length, 2);
    for (var i = 0; i < 15; i++) {
      book.remember(
        PlacePair(KakaoPlace('역$i', '', 126.9 + i / 1000, 37.5), end),
      );
    }
    expect(book.recent.length, 10);
    expect(book.recent.first.start.name, '역14');
  });
  test('malformed saved places do not discard valid favorites', () {
    final book = PlaceBook.fromJson({
      'favorites': [
        null,
        {
          'start': {'x': 'NaN'},
        },
        pair.toJson(),
        pair.toJson(),
      ],
      'start': {'x': 'NaN', 'y': 37.5, 'place_name': 'bad'},
    });
    expect(book.favorites.single.title, '출근');
    expect(book.start, isNull);
    final encoded = jsonEncode(book.toJson());
    expect(encoded, isNot(contains('apiKey')));
    expect(encoded, isNot(contains('deadline')));
    expect(encoded, isNot(contains('points')));
  });
  test('bookmark names update without creating duplicate entries', () {
    final book = PlaceBook()
      ..bookmark(pair)
      ..bookmark(const PlacePair(start, end, name: '회사'));
    expect(book.favorites.single.title, '회사');
  });
  group('place storage', () {
    late Directory folder;
    late File file;
    late PlaceBookStore store;
    setUp(() async {
      folder = await Directory.systemTemp.createTemp('bark-place-book-test-');
      file = File('${folder.path}/places.json');
      store = PlaceBookStore(file);
    });
    tearDown(() async {
      await folder.delete(recursive: true);
    });
    test('ordered snapshot writes preserve the latest selection', () async {
      final book = PlaceBook(start: start, end: end)..bookmark(pair);
      final first = store.save(book);
      book.start = end;
      book.end = start;
      final second = store.save(book);
      await Future.wait([first, second]);
      final loaded = await store.load();
      expect(loaded.start!.name, '강남역');
      expect(loaded.end!.name, '서울역');
      expect(loaded.favorites.single.title, '출근');
    });
    test(
      'corrupt primary recovers from backup and does not overwrite it',
      () async {
        final book = PlaceBook(start: start, end: end)..bookmark(pair);
        await store.save(book);
        await store.save(book);
        await file.writeAsString('{bad json');
        final recovered = await store.load();
        expect(recovered.favorites.single.title, '출근');
        recovered.start = end;
        await store.save(recovered);
        final backup = PlaceBook.fromJson(
          jsonDecode(await File('${file.path}.bak').readAsString()),
        );
        expect(backup.start!.name, '서울역');
        expect((await store.load()).start!.name, '강남역');
      },
    );
    test(
      'unrecoverable file reports an error instead of pretending it is empty',
      () async {
        await file.writeAsString('bad');
        await expectLater(store.load(), throwsFormatException);
      },
    );
  });
}
