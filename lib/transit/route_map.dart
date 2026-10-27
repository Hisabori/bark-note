import 'package:flutter/material.dart';
import 'kakao_api.dart';
import 'map_geometry.dart';

Color legColor(String type) => switch (type) {
  'BUS' => const Color(0xff1967d2),
  'SUBWAY' => const Color(0xff823fbd),
  _ => const Color(0xff57636b),
};
IconData legIcon(String type) => switch (type) {
  'BUS' => Icons.directions_bus,
  'SUBWAY' => Icons.subway,
  _ => Icons.directions_walk,
};

class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.route,
    required this.start,
    required this.end,
    required this.apiKey,
    this.fullscreen = false,
  });
  final KakaoRoute route;
  final KakaoPlace start, end;
  final String apiKey;
  final bool fullscreen;
  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final transform = TransformationController();
  int selected = -1, retry = 0;
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route || oldWidget.apiKey != widget.apiKey) {
      selected = -1;
      transform.value = Matrix4.identity();
    }
  }

  @override
  Widget build(BuildContext context) {
    final legs = widget.route.legs;
    final points = legs
        .expand((s) => s.points.whereType<RoutePoint>())
        .toList();
    final start = RoutePoint(widget.start.x, widget.start.y),
        end = RoutePoint(widget.end.x, widget.end.y);
    final viewport = RouteViewport([...points, start, end]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '경로 지도',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: '전체 경로 보기',
              onPressed: () => transform.value = Matrix4.identity(),
              icon: const Icon(Icons.fit_screen),
            ),
            if (!widget.fullscreen)
              IconButton(
                tooltip: '지도 크게 보기',
                icon: const Icon(Icons.fullscreen),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: Text(
                          '${widget.start.name} → ${widget.end.name}',
                        ),
                      ),
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: RouteMap(
                          route: widget.route,
                          start: widget.start,
                          end: widget.end,
                          apiKey: widget.apiKey,
                          fullscreen: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (points.length < 2)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('이 경로는 선을 그릴 좌표가 제공되지 않았습니다. 아래 구간 안내를 확인하세요.'),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1.5,
              child: InteractiveViewer(
                transformationController: transform,
                minScale: 1,
                maxScale: 5,
                child: Image.network(
                  viewport.uri.toString(),
                  key: ValueKey(
                    '${viewport.uri}:$retry:${widget.apiKey.hashCode}',
                  ),
                  headers: {'Authorization': 'KakaoAK ${widget.apiKey.trim()}'},
                  fit: BoxFit.fill,
                  frameBuilder: (context, child, frame, synchronous) =>
                      frame == null
                      ? const Center(child: CircularProgressIndicator())
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            child,
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _RoutePainter(
                                  viewport,
                                  legs,
                                  start,
                                  end,
                                  selected,
                                ),
                              ),
                            ),
                          ],
                        ),
                  errorBuilder: (context, error, stack) => ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined),
                          const Text(
                            '지도를 불러오지 못했습니다.\n인터넷 연결·카카오 지도 API 권한을 확인하세요.',
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () => setState(() => retry++),
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '파랑 버스 · 보라 지하철 · 회색 점선 도보\n두 손가락으로 확대하고 드래그하세요. 지도·경로 © Kakao',
          ),
        ),
        for (var i = 0; i < legs.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            selected: selected == i,
            leading: CircleAvatar(
              backgroundColor: legColor(legs[i].type),
              foregroundColor: Colors.white,
              child: Icon(legIcon(legs[i].type)),
            ),
            title: Text(
              '${legs[i].label}${legs[i].vehicles.isEmpty ? '' : ' ${legs[i].vehicles.join(' / ')}'} · ${(legs[i].seconds / 60).ceil()}분',
            ),
            subtitle: Text(
              legs[i].stops.isEmpty
                  ? legs[i].guidance
                  : '${legs[i].stops.first} → ${legs[i].stops.last}\n${legs[i].guidance}',
            ),
            onTap: () => setState(() => selected = selected == i ? -1 : i),
          ),
        if (selected >= 0 && legs[selected].stops.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('경유 정류장: ${legs[selected].stops.join(' → ')}'),
          ),
      ],
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.viewport, this.legs, this.start, this.end, this.selected);
  final RouteViewport viewport;
  final List<KakaoLeg> legs;
  final RoutePoint start, end;
  final int selected;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / RouteViewport.width,
      size.height / RouteViewport.height,
    );
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final path = Path();
      var move = true;
      for (final point in leg.points) {
        if (point == null) {
          move = true;
          continue;
        }
        final pixel = viewport.pixel(point);
        if (move) {
          path.moveTo(pixel.x, pixel.y);
          move = false;
        } else {
          path.lineTo(pixel.x, pixel.y);
        }
      }
      final color = selected < 0 || selected == i
          ? legColor(leg.type)
          : legColor(leg.type).withValues(alpha: 0.25);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (leg.type == 'WALKING') {
        for (final metric in path.computeMetrics()) {
          for (double d = 0; d < metric.length; d += 20) {
            canvas.drawPath(metric.extractPath(d, d + 9), paint);
          }
        }
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 15
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.drawPath(path, paint);
      }
    }
    void marker(RoutePoint point, String text, Color color) {
      final pixel = viewport.pixel(point),
          offset = Offset(viewport.pixel(point).x, viewport.pixel(point).y);
      canvas.drawCircle(offset, 19, Paint()..color = Colors.white);
      canvas.drawCircle(offset, 15, Paint()..color = color);
      final label = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(pixel.x - label.width / 2, pixel.y - label.height / 2),
      );
    }

    marker(start, '출', const Color(0xff14734a));
    marker(end, '도', const Color(0xffc42b36));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) => true;
}
