import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'current_location.dart';
import 'kakao_api.dart';
import 'map_camera.dart';

class MapPlaceChoice {
  const MapPlaceChoice(this.place, this.origin);
  final KakaoPlace place;
  final bool origin;
}

class MapExplorer extends StatefulWidget {
  const MapExplorer({
    super.key,
    required this.apiKey,
    this.center,
    this.api,
    this.locationReader,
  });
  final String apiKey;
  final KakaoPlace? center;
  final KakaoApi? api;
  final Future<LocationFix> Function()? locationReader;
  @override
  State<MapExplorer> createState() => _MapExplorerState();
}

class _MapExplorerState extends State<MapExplorer> {
  final query = TextEditingController();
  late PlaceMapCamera camera;
  List<KakaoPlace> places = [];
  KakaoPlace? selected;
  bool loading = false, locating = false;
  String message = '';
  int radius = 1000, generation = 0, retry = 0;
  @override
  void initState() {
    super.initState();
    camera = PlaceMapCamera(
      widget.center ?? const KakaoPlace('서울시청', '', 126.9780, 37.5665),
    );
  }

  @override
  void dispose() {
    generation++;
    query.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    if (loading || locating) return;
    final token = ++generation;
    setState(() {
      locating = true;
      message = '';
    });
    try {
      final fix = await (widget.locationReader ?? ForegroundLocation().read)();
      if (!mounted || token != generation) return;
      setState(() {
        camera = PlaceMapCamera(fix.place);
        selected = fix.place;
        places = [];
        message =
            '이번에 확인한 위치 · 오차 약 ${fix.accuracy.ceil()}m. 실제 출입구 위치를 확인해주세요.';
      });
    } on TimeoutException {
      if (mounted && token == generation) {
        setState(() => message = '위치 확인 시간이 초과됐어요. 다시 시도하거나 장소 이름으로 검색해주세요.');
      }
    } catch (e) {
      if (mounted && token == generation) {
        setState(() => message = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted && token == generation) setState(() => locating = false);
    }
  }

  Future<void> search({String? category, bool veterinary = false}) async {
    if (loading || locating) return;
    final token = ++generation;
    final center = camera.center;
    setState(() {
      loading = true;
      message = '';
      places = [];
      selected = null;
    });
    try {
      final api = widget.api ?? KakaoApi(widget.apiKey);
      final result = category != null
          ? await api.nearby(category, center, radius)
          : veterinary
          ? await api.search('동물병원', near: center, radius: radius)
          : await api.search(query.text);
      if (!mounted || token != generation) return;
      setState(() {
        places = result;
        selected = result.firstOrNull;
        if (category == null && !veterinary && selected != null) {
          camera = PlaceMapCamera(selected!);
        }
        message = result.isEmpty
            ? '검색 결과가 없어요. 지도 중심이나 반경을 바꿔보세요.'
            : '${result.length}개 장소 · 번호를 누르거나 목록에서 선택하세요.${category != null || veterinary ? ' 지도 중심 반경 ${radius}m 기준입니다.' : ''}';
      });
    } catch (e) {
      if (mounted && token == generation) {
        setState(() => message = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted && token == generation) setState(() => loading = false);
    }
  }

  void move(double east, double north) => setState(() {
    camera = camera.move(east, north);
    message = '지도 중심을 이동했어요. 주변 분류를 눌러 이 위치에서 다시 검색하세요.';
  });
  void select(KakaoPlace place) => setState(() {
    selected = place;
    camera = PlaceMapCamera(place, level: camera.level);
  });
  List<KakaoPlace> get pins => places.isNotEmpty ? places : [?selected];
  Widget map() => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 1.5,
          child: GestureDetector(
            onTapUp: (details) {
              if (loading || locating) return;
              KakaoPlace? nearest;
              var distance = 28.0;
              for (final place in pins) {
                final pixel = camera.pixel(place);
                final offset = Offset(
                  pixel.x * width / PlaceMapCamera.width,
                  pixel.y * width / PlaceMapCamera.width,
                );
                final d = (details.localPosition - offset).distance;
                if (d < distance) {
                  distance = d;
                  nearest = place;
                }
              }
              if (nearest != null) select(nearest);
            },
            child: Image.network(
              camera.uri.toString(),
              key: ValueKey('${camera.uri}:$retry:${widget.apiKey.hashCode}'),
              headers: {'Authorization': 'KakaoAK ${widget.apiKey.trim()}'},
              fit: BoxFit.fill,
              frameBuilder: (context, child, frame, synchronous) =>
                  frame == null
                  ? const ColoredBox(
                      color: Color(0xffe9efed),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        child,
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _PlacePins(camera, pins, selected),
                          ),
                        ),
                      ],
                    ),
              errorBuilder: (context, error, stack) => ColoredBox(
                color: const Color(0xffe9efed),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '지도 이미지를 불러오지 못했어요.\n장소 목록은 계속 사용할 수 있습니다.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => setState(() => retry++),
                        child: const Text('지도 다시 불러오기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('주변 지도')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: '전국 장소 검색',
              hintText: '장소·역·건물 이름',
              suffixIcon: IconButton(
                tooltip: '장소 검색',
                onPressed: loading || locating ? null : () => search(),
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => search(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: loading || locating ? null : locate,
                icon: const Icon(Icons.my_location),
                label: const Text('내 위치'),
              ),
              DropdownButton<int>(
                value: radius,
                items: const [
                  DropdownMenuItem(value: 500, child: Text('주변 500m')),
                  DropdownMenuItem(value: 1000, child: Text('주변 1km')),
                  DropdownMenuItem(value: 3000, child: Text('주변 3km')),
                ],
                onChanged: loading || locating
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            radius = value;
                            camera = PlaceMapCamera(
                              camera.center,
                              level: value == 500
                                  ? 4
                                  : value == 3000
                                  ? 7
                                  : 5,
                            );
                          });
                        }
                      },
              ),
            ],
          ),
          const Text(
            '내 위치는 버튼을 눌렀을 때 한 번 확인합니다. 위치 기반 검색·길찾기에는 선택한 위치가 카카오로 전달됩니다. 출발·도착으로 선택한 장소는 기기에 저장됩니다.',
          ),
          const SizedBox(height: 12),
          map(),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 2,
            children: [
              IconButton(
                tooltip: '서쪽으로 지도 이동',
                onPressed: loading || locating ? null : () => move(-1, 0),
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                tooltip: '북쪽으로 지도 이동',
                onPressed: loading || locating ? null : () => move(0, 1),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: '남쪽으로 지도 이동',
                onPressed: loading || locating ? null : () => move(0, -1),
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: '동쪽으로 지도 이동',
                onPressed: loading || locating ? null : () => move(1, 0),
                icon: const Icon(Icons.arrow_forward),
              ),
              IconButton(
                tooltip: '지도 확대',
                onPressed: loading || locating
                    ? null
                    : () => setState(() => camera = camera.zoom(-1)),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: '지도 축소',
                onPressed: loading || locating
                    ? null
                    : () => setState(() => camera = camera.zoom(1)),
                icon: const Icon(Icons.remove),
              ),
            ],
          ),
          const Text('지도·장소 © Kakao · 이동 버튼으로 중심을 옮긴 뒤 주변 장소를 검색하세요.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final category in {
                'SW8': '지하철역',
                'CE7': '카페',
                'CS2': '편의점',
                'FD6': '음식점',
                'PM9': '약국',
              }.entries)
                ActionChip(
                  label: Text(category.value),
                  onPressed: loading || locating
                      ? null
                      : () => search(category: category.key),
                ),
              ActionChip(
                label: const Text('동물병원'),
                onPressed: loading || locating
                    ? null
                    : () => search(veterinary: true),
              ),
            ],
          ),
          if (loading || locating)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(message),
            ),
          if (selected != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected!.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(selected!.address),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: loading || locating
                              ? null
                              : () => Navigator.pop(
                                  context,
                                  MapPlaceChoice(selected!, true),
                                ),
                          child: const Text('출발지로 선택'),
                        ),
                        FilledButton.tonal(
                          onPressed: loading || locating
                              ? null
                              : () => Navigator.pop(
                                  context,
                                  MapPlaceChoice(selected!, false),
                                ),
                          child: const Text('도착지로 선택'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text: '${selected!.name} ${selected!.address}',
                              ),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('장소 정보를 복사했어요.')),
                              );
                            }
                          },
                          child: const Text('주소 복사'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          for (var i = 0; i < places.length; i++)
            ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              selected: identical(selected, places[i]),
              title: Text(places[i].name),
              subtitle: Text(places[i].address),
              onTap: loading || locating ? null : () => select(places[i]),
            ),
        ],
      ),
    ),
  );
}

class _PlacePins extends CustomPainter {
  _PlacePins(this.camera, this.places, this.selected);
  final PlaceMapCamera camera;
  final List<KakaoPlace> places;
  final KakaoPlace? selected;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(
      size.width / PlaceMapCamera.width,
      size.height / PlaceMapCamera.height,
    );
    for (var i = 0; i < places.length; i++) {
      final p = camera.pixel(places[i]);
      // Leave the provider logo unobstructed.
      if (p.x < 210 && p.y > PlaceMapCamera.height - 100) continue;
      final offset = Offset(p.x, p.y);
      canvas.drawCircle(offset, 30, Paint()..color = Colors.white);
      canvas.drawCircle(
        offset,
        25,
        Paint()
          ..color = identical(selected, places[i])
              ? const Color(0xffb3261e)
              : const Color(0xff1967d2),
      );
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, offset - Offset(text.width / 2, text.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlacePins old) =>
      old.camera != camera || old.places != places || old.selected != selected;
}
