import 'package:geolocator/geolocator.dart';
import 'kakao_api.dart';

class LocationFix {
  const LocationFix(this.place, this.accuracy);
  final KakaoPlace place;
  final double accuracy;
}

/// One foreground fix; never starts a stream or a background service.
class ForegroundLocation {
  ForegroundLocation({
    Future<bool> Function()? services,
    Future<LocationPermission> Function()? permission,
    Future<LocationPermission> Function()? request,
    Future<Position> Function()? position,
  }) : services = services ?? Geolocator.isLocationServiceEnabled,
       permission = permission ?? Geolocator.checkPermission,
       request = request ?? Geolocator.requestPermission,
       position =
           position ??
           (() => Geolocator.getCurrentPosition(
             locationSettings: const LocationSettings(
               accuracy: LocationAccuracy.high,
               timeLimit: Duration(seconds: 20),
             ),
           ));
  final Future<bool> Function() services;
  final Future<LocationPermission> Function() permission, request;
  final Future<Position> Function() position;
  Future<LocationFix> read() async {
    if (!await services()) {
      throw StateError('기기의 위치 서비스를 켜주세요. 장소 이름으로도 검색할 수 있습니다.');
    }
    var access = await permission();
    if (access == LocationPermission.denied) access = await request();
    if (access != LocationPermission.whileInUse &&
        access != LocationPermission.always) {
      throw StateError(
        access == LocationPermission.deniedForever
            ? '위치 권한이 차단되어 있습니다. 기기 설정에서 허용하거나 장소를 직접 검색해주세요.'
            : '위치 권한 없이도 장소 이름으로 검색할 수 있습니다.',
      );
    }
    final p = await position();
    if (!p.longitude.isFinite ||
        !p.latitude.isFinite ||
        p.longitude.abs() > 180 ||
        p.latitude.abs() > 90 ||
        !p.accuracy.isFinite ||
        p.accuracy < 0 ||
        DateTime.now().difference(p.timestamp).abs() >
            const Duration(minutes: 1)) {
      throw StateError('새 위치를 확인하지 못했습니다. 다시 시도하거나 장소를 직접 선택해주세요.');
    }
    return LocationFix(
      KakaoPlace(
        '내 위치 (선택 시점)',
        '확인 ${p.timestamp.toLocal().toIso8601String().substring(0, 16).replaceAll('T', ' ')} · 오차 약 ${p.accuracy.ceil()}m',
        p.longitude,
        p.latitude,
      ),
      p.accuracy,
    );
  }
}
