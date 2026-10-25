import 'package:flutter/material.dart';
import 'package:bark_note/transit/map_explorer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bark_note/transit/current_location.dart';
import 'package:bark_note/transit/kakao_api.dart';
import 'package:bark_note/transit/map_camera.dart';

Position fix({double x = 127.0, double y = 37.5, int age = 0}) => Position(
  longitude: x,
  latitude: y,
  timestamp: DateTime.now().subtract(Duration(seconds: age)),
  accuracy: 25,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class TestPlacesApi extends KakaoApi {
  TestPlacesApi() : super('unused');
  @override
  Future<List<KakaoPlace>> nearby(
    String category,
    KakaoPlace center,
    int radius,
  ) async => [const KakaoPlace('테스트역', '서울', 127, 37.5)];
}

void main() {
  test('disabled location never asks permission or reads GPS', () async {
    var requested = false, read = false;
    final service = ForegroundLocation(
      services: () async => false,
      permission: () async => LocationPermission.denied,
      request: () async {
        requested = true;
        return LocationPermission.whileInUse;
      },
      position: () async {
        read = true;
        return fix();
      },
    );
    await expectLater(service.read(), throwsStateError);
    expect(requested, false);
    expect(read, false);
  });
  test('denied and permanently denied access never read GPS', () async {
    for (final permission in [
      LocationPermission.denied,
      LocationPermission.deniedForever,
    ]) {
      var reads = 0, requests = 0;
      final service = ForegroundLocation(
        services: () async => true,
        permission: () async => permission,
        request: () async {
          requests++;
          return LocationPermission.denied;
        },
        position: () async {
          reads++;
          return fix();
        },
      );
      await expectLater(service.read(), throwsStateError);
      expect(reads, 0);
      expect(requests, permission == LocationPermission.denied ? 1 : 0);
    }
  });
  test(
    'one fresh authorized fix preserves coordinates and uncertainty',
    () async {
      var reads = 0;
      final service = ForegroundLocation(
        services: () async => true,
        permission: () async => LocationPermission.whileInUse,
        position: () async {
          reads++;
          return fix();
        },
      );
      final value = await service.read();
      expect(reads, 1);
      expect(value.place.x, 127);
      expect(value.place.y, 37.5);
      expect(value.accuracy, 25);
    },
  );
  test('stale and invalid fixes are rejected', () async {
    for (final point in [fix(age: 120), fix(x: 200), fix(y: double.nan)]) {
      final service = ForegroundLocation(
        services: () async => true,
        permission: () async => LocationPermission.whileInUse,
        position: () async => point,
      );
      await expectLater(service.read(), throwsStateError);
    }
  });
  test('map center, zoom limits and movement agree with camera', () {
    const place = KakaoPlace('center', '', 127, 37.5);
    const camera = PlaceMapCamera(place);
    expect(camera.pixel(place).x, 480);
    expect(camera.pixel(place).y, 320);
    expect(camera.move(1, 0).center.x, greaterThan(place.x));
    expect(camera.move(0, 1).center.y, greaterThan(place.y));
    expect(camera.zoom(-100).level, 1);
    expect(camera.zoom(100).level, 15);
    expect(camera.zoom(1).metresPerPixel, camera.metresPerPixel * 2);
    expect(camera.uri.queryParameters['center'], '127.0,37.5');
    expect(camera.uri.toString(), isNot(contains('KakaoAK')));
  });
  test('nearby search keeps longitude latitude and rejects invalid radius', () {
    const place = KakaoPlace('center', '', 127, 37.5);
    final parameters = KakaoApi.nearbyParameters(place, 1000);
    expect(parameters, {
      'x': '127.0',
      'y': '37.5',
      'radius': '1000',
      'sort': 'distance',
    });
    expect(() => KakaoApi.nearbyParameters(place, 0), throwsFormatException);
    expect(
      () => KakaoApi.nearbyParameters(place, 20001),
      throwsFormatException,
    );
  });
  test('empty road address falls back to provider lot address', () {
    final place = KakaoPlace.fromJson({
      'place_name': 'A',
      'x': '127',
      'y': '37.5',
      'road_address_name': '',
      'address_name': '서울',
    });
    expect(place.address, '서울');
  });
  testWidgets(
    'nearby place selection returns a destination without reading GPS',
    (tester) async {
      var locationReads = 0;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Scaffold()),
      );
      final result = navigator.currentState!.push<MapPlaceChoice>(
        MaterialPageRoute(
          builder: (_) => MapExplorer(
            apiKey: 'unused',
            api: TestPlacesApi(),
            locationReader: () async {
              locationReads++;
              return const LocationFix(KakaoPlace('내 위치', '', 127, 37.5), 25);
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(locationReads, 0);
      await tester.scrollUntilVisible(
        find.text('지하철역'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('지하철역'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('도착지로 선택'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('도착지로 선택'));
      await tester.pump(const Duration(milliseconds: 400));
      final choice = await result;
      expect(choice!.place.name, '테스트역');
      expect(choice.origin, false);
      expect(locationReads, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

