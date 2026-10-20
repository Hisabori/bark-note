import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

String crowdStation(String value) => value
    .replaceAll(RegExp(r'\([^)]*\)'), '')
    .replaceAll(' ', '')
    .replaceFirst(RegExp(r'역$'), '');
String crowdDirection(String value) =>
    const {'상행': '상선', '하행': '하선'}[value] ?? value;

class CrowdProfile {
  CrowdProfile(this.day, this.line, this.station, this.direction, this.slots);
  final String day, line, station, direction;
  final Map<int, double> slots;
}

class CrowdData {
  CrowdData(this.profiles, this.asOf, this.source);
  final List<CrowdProfile> profiles;
  final String asOf, source;
  static Future<CrowdData>? _loaded;
  static Future<CrowdData> load() => _loaded ??= _load();
  static Future<CrowdData> _load() async {
    final bytes = await rootBundle.load(
      'assets/transit/crowd-20260630.json.gz',
    );
    return CrowdData.fromJson(
      jsonDecode(
            utf8.decode(
              gzip.decode(
                bytes.buffer.asUint8List(
                  bytes.offsetInBytes,
                  bytes.lengthInBytes,
                ),
              ),
            ),
          )
          as Map<String, dynamic>,
    );
  }

  factory CrowdData.fromJson(Map<String, dynamic> data) {
    final headers = (data['headers'] as List).cast<String>();
    final columns = <int, int>{};
    for (var c = 5; c < headers.length; c++) {
      final m = RegExp(r'^(\d+)시(\d+)분$').firstMatch(headers[c].trim());
      if (m != null) columns[c] = int.parse(m[1]!) * 60 + int.parse(m[2]!);
    }
    if (columns.length < 30) throw const FormatException('혼잡도 시간대 형식 오류');
    final profiles = <CrowdProfile>[];
    for (final raw in data['rows'] as List) {
      final row = (raw as List).map((v) => v.toString().trim()).toList();
      if (row.length != headers.length) {
        throw const FormatException('혼잡도 열 개수 오류');
      }
      final slots = <int, double>{};
      for (final c in columns.entries) {
        final value = double.tryParse(row[c.key]);
        if (value != null && value.isFinite && value >= 0) {
          slots[c.value] = value;
        }
      }
      profiles.add(CrowdProfile(row[0], row[1], row[3], row[4], slots));
    }
    return CrowdData(
      profiles,
      data['asOf'] as String,
      data['source'] as String,
    );
  }
  List<CrowdProfile> forStation(String station, String line) => profiles
      .where(
        (p) =>
            crowdStation(p.station) == crowdStation(station) && p.line == line,
      )
      .toList();
}
