import 'dart:convert';
import 'dart:io';

/// Serialized snapshots with a last-valid backup. Never overwrites an unreadable store.
class JsonSnapshotStore {
  JsonSnapshotStore({
    required Future<File> Function() file,
    required this.accepts,
  }) : _file = file();
  final Future<File> _file;
  final bool Function(Object?) accepts;
  Future<Object?>? _loaded;
  bool recovered = false;
  Future<void> _pending = Future<void>.value();
  Object? decode(String text) {
    final value = jsonDecode(text);
    if (!accepts(value)) throw const FormatException('저장 형식이 올바르지 않습니다.');
    return value;
  }

  Future<Object?> read() => _loaded ??= _read();
  Future<Object?> _read() async {
    final file = await _file;
    var found = false;
    for (final candidate in [file, File('${file.path}.bak')]) {
      if (!await candidate.exists()) continue;
      found = true;
      try {
        final value = decode(await candidate.readAsString());
        recovered = candidate.path != file.path;
        return value;
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    if (found) {
      throw const FormatException('저장 파일을 읽지 못했습니다. 기존 파일을 보존하고 저장을 중단합니다.');
    }
    return null;
  }

  Future<void> write(Object value) {
    final snapshot = jsonEncode(value);
    decode(snapshot);
    final next = _pending.then((_) async {
      await read();
      final file = await _file;
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(snapshot, flush: true);
      if (await file.exists()) {
        final previous = await file.readAsString();
        try {
          decode(previous);
          await File('${file.path}.bak').writeAsString(previous, flush: true);
        } on FormatException {
          /* Preserve the known-good recovery backup. */
        }
      }
      await temporary.rename(file.path);
      _loaded = Future<Object?>.value(jsonDecode(snapshot));
    });
    _pending = next.catchError((Object _) {});
    return next;
  }
}
