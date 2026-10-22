import 'dart:convert';
import 'dart:io';
import 'kakao_api.dart';

class PlacePair {
  const PlacePair(this.start, this.end, {this.name = ''});
  final KakaoPlace start, end;
  final String name;
  String get title => name.isEmpty ? '${start.name} → ${end.name}' : name;
  String get id => [
    start.x,
    start.y,
    end.x,
    end.y,
  ].map((v) => v.toStringAsFixed(6)).join('|');
  Map<String, dynamic> toJson() => {
    'start': start.toJson(),
    'end': end.toJson(),
    'name': name,
  };
  static PlacePair? parse(dynamic value) {
    try {
      if (value is! Map || value['start'] is! Map || value['end'] is! Map) {
        return null;
      }
      final start = KakaoPlace.fromJson(
        Map<String, dynamic>.from(value['start']),
      );
      final end = KakaoPlace.fromJson(Map<String, dynamic>.from(value['end']));
      if (start.name.trim().isEmpty ||
          end.name.trim().isEmpty ||
          start.name == 'null' ||
          end.name == 'null') {
        return null;
      }
      return PlacePair(
        start,
        end,
        name: value['name'] is String ? value['name'] : '',
      );
    } catch (_) {
      return null;
    }
  }
}

class PlaceBook {
  PlaceBook({
    this.start,
    this.end,
    List<PlacePair>? favorites,
    List<PlacePair>? recent,
  }) : favorites = favorites ?? [],
       recent = recent ?? [];
  KakaoPlace? start, end;
  List<PlacePair> favorites, recent;
  void remember(PlacePair pair) {
    recent = [pair, ...recent.where((p) => p.id != pair.id)].take(10).toList();
  }

  void bookmark(PlacePair pair) {
    favorites = [
      pair,
      ...favorites.where((p) => p.id != pair.id),
    ].take(10).toList();
  }

  Map<String, dynamic> toJson() => {
    'start': start?.toJson(),
    'end': end?.toJson(),
    'favorites': favorites.map((p) => p.toJson()).toList(),
    'recent': recent.map((p) => p.toJson()).toList(),
  };
  factory PlaceBook.fromJson(Map data) {
    KakaoPlace? place(dynamic value) {
      try {
        if (value is! Map ||
            value['place_name'] is! String ||
            (value['place_name'] as String).trim().isEmpty) {
          return null;
        }
        return KakaoPlace.fromJson(Map<String, dynamic>.from(value));
      } catch (_) {
        return null;
      }
    }

    List<PlacePair> pairs(dynamic values) {
      if (values is! List) return [];
      final seen = <String>{};
      return values
          .map(PlacePair.parse)
          .whereType<PlacePair>()
          .where((p) => seen.add(p.id))
          .take(10)
          .toList();
    }

    return PlaceBook(
      start: place(data['start']),
      end: place(data['end']),
      favorites: pairs(data['favorites']),
      recent: pairs(data['recent']),
    );
  }
}

class PlaceBookStore {
  PlaceBookStore(this.file);
  final File file;
  Future<void> _pending = Future.value();
  Future<PlaceBook> load() async {
    Object? failure;
    for (final candidate in [file, File('${file.path}.bak')]) {
      if (!await candidate.exists()) continue;
      try {
        final data = jsonDecode(await candidate.readAsString());
        if (data is! Map) throw const FormatException('Invalid place book');
        return PlaceBook.fromJson(data);
      } catch (e) {
        failure = e;
      }
    }
    if (failure != null) {
      throw const FormatException('저장된 장소를 읽지 못했습니다. 새 장소를 입력해주세요.');
    }
    return PlaceBook();
  }

  Future<void> save(PlaceBook book) {
    // Capture now, then serialize writes so an older snapshot cannot win.
    final snapshot = jsonEncode(book.toJson());
    final operation = _pending.then((_) async {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(snapshot, flush: true);
      if (await file.exists()) {
        // Preserve the last valid backup if the primary was corrupt.
        try {
          final data = jsonDecode(await file.readAsString());
          if (data is Map) await file.copy('${file.path}.bak');
        } on FormatException {
          /* Keep the valid backup. */
        }
      }
      await temp.rename(file.path);
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}
