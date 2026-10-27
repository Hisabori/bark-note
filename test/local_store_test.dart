import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bark_note/local_store.dart';

void main() {
  late Directory folder;
  late File file;
  late JsonSnapshotStore store;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('bark-store-');
    file = File('${folder.path}/history.json');
    store = JsonSnapshotStore(
      file: () async => file,
      accepts: (value) => value is List,
    );
  });
  tearDown(() async {
    expect(
      folder.absolute.path.startsWith(
        '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}',
      ),
      isTrue,
    );
    await folder.delete(recursive: true);
  });
  test('queued saves capture snapshots and retain latest data', () async {
    final values = [
      {'value': 1},
    ];
    final first = store.write(values);
    values.first['value'] = 2;
    final second = store.write(values);
    values.first['value'] = 99;
    await Future.wait([first, second]);
    expect(jsonDecode(await file.readAsString()), [
      {'value': 2},
    ]);
    expect(jsonDecode(await File('${file.path}.bak').readAsString()), [
      {'value': 1},
    ]);
  });
  test('corrupt primary recovers without overwriting valid backup', () async {
    await file.writeAsString('{broken');
    await File('${file.path}.bak').writeAsString('[{"value":3}]');
    expect(await store.read(), [
      {'value': 3},
    ]);
    await store.write([
      {'value': 4},
    ]);
    expect(jsonDecode(await file.readAsString()), [
      {'value': 4},
    ]);
    expect(jsonDecode(await File('${file.path}.bak').readAsString()), [
      {'value': 3},
    ]);
  });
  test('unrecoverable data is preserved and writes are refused', () async {
    await file.writeAsString('corrupt');
    await expectLater(store.read(), throwsFormatException);
    await expectLater(
      store.write([
        {'new': 1},
      ]),
      throwsFormatException,
    );
    expect(await file.readAsString(), 'corrupt');
    expect(await File('${file.path}.tmp').exists(), false);
  });
  test('wrong root type falls back to a valid backup', () async {
    await file.writeAsString('{"unexpected":true}');
    await File('${file.path}.bak').writeAsString('[]');
    expect(await store.read(), isEmpty);
  });
}
