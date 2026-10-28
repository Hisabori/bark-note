import 'dart:math' as math;
import 'package:flutter/material.dart';

String crowdTime(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
Color crowdColor(double value) => value < 50
    ? const Color(0xff138477)
    : value < 100
    ? const Color(0xffb37916)
    : const Color(0xffcf5547);

/// Official snapshot values only. Gaps are shown as gaps, never zero-filled.
class CrowdTimeline extends StatefulWidget {
  const CrowdTimeline({
    super.key,
    required this.slots,
    required this.boardMinute,
  });
  final Map<int, double> slots;
  final int boardMinute;
  @override
  State<CrowdTimeline> createState() => _CrowdTimelineState();
}

class _CrowdTimelineState extends State<CrowdTimeline> {
  int? selected;
  late final ScrollController scroll;
  List<int> get times {
    final keys = widget.slots.keys.toList()..sort();
    if (keys.isEmpty) return [];
    return [for (var t = keys.first; t <= keys.last; t += 30) t];
  }

  int? get initial => widget.slots.containsKey(widget.boardMinute)
      ? widget.boardMinute
      : times.firstOrNull;
  @override
  void initState() {
    super.initState();
    selected = initial;
    scroll = ScrollController(
      initialScrollOffset: math
          .max(0, times.indexOf(initial ?? -1) * 104 - 104)
          .toDouble(),
    );
  }

  @override
  void didUpdateWidget(CrowdTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slots != widget.slots ||
        oldWidget.boardMinute != widget.boardMinute) {
      selected = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) {
          scroll.jumpTo(
            math
                .max(0, times.indexOf(initial ?? -1) * 104 - 104)
                .toDouble()
                .clamp(0, scroll.position.maxScrollExtent),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keys = times;
    if (keys.isEmpty) return const Text('표시할 시간대 통계가 없습니다.');
    final v = widget.slots[selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Text(
          '객차 안은 이 정도',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '${selected == null ? '' : crowdTime(selected!)} · ${v == null ? '통계 없음' : '평균 ${v.toStringAsFixed(1)}%'}${selected == widget.boardMinute ? ' · 예상 탑승 시간대' : ''}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Semantics(
          label: v == null
              ? '해당 시간대 통계가 없어 사람 밀집도를 표시하지 않습니다'
              : '객차 밀집도 예시, 평균 ${v.toStringAsFixed(1)}퍼센트. 사람 아이콘 수는 실제 인원이 아닙니다.',
          image: true,
          child: AspectRatio(
            aspectRatio: 1.85,
            child: CustomPaint(
              key: const ValueKey('crowd-carriage'),
              painter: CrowdCarriagePainter(v),
              child: v == null
                  ? const Center(
                      child: Icon(
                        Icons.help_outline_rounded,
                        color: Color(0xff8391a1),
                        size: 42,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          v == null
              ? '이 시간대는 통계가 없어요.'
              : v < 50
              ? '사람 사이에 비교적 공간이 있는 모습'
              : v < 100
              ? '서 있는 사람이 늘어나는 모습'
              : '사람이 가까이 모여 있는 모습',
          style: TextStyle(
            color: v == null ? const Color(0xff657487) : crowdColor(v),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '시간대를 눌러 객차의 밀집 모습을 비교해요.',
          style: TextStyle(fontSize: 13, color: Color(0xff657487)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(14) * 2 + 32,
          child: ListView.builder(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            itemExtent: 104,
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final minute = keys[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: ChoiceChip(
                    label: Text(crowdTime(minute)),
                    selected: selected == minute,
                    onSelected: (_) => setState(() => selected = minute),
                    avatar: minute == widget.boardMinute
                        ? const Icon(Icons.schedule, size: 15)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '통계 평균을 한 객차의 밀집 모습으로 표현한 예시입니다. 실제 인원·칸별 혼잡도·좌석 배치가 아니며, 빈 통계는 빈 객차로 표시하지 않습니다.',
          style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xff657487)),
        ),
        if (v != null && v > 200)
          const Text(
            '그림은 최대 밀집 모습으로 표시하며, 위의 실제 통계 비율은 그대로 유지합니다.',
            style: TextStyle(fontSize: 12),
          ),
      ],
    );
  }
}

/// A schematic carriage, with evenly distributed silhouettes rather than bars.
class CrowdCarriagePainter extends CustomPainter {
  CrowdCarriagePainter(this.value);
  final double? value;
  @override
  void paint(Canvas canvas, Size size) {
    final car = Rect.fromLTWH(6, 6, size.width - 12, size.height - 12);
    final outline = Paint()
      ..color = const Color(0xffa7b5c6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(car, const Radius.circular(27)),
      Paint()..color = const Color(0xfff3f7fc),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(car, const Radius.circular(27)),
      outline,
    );
    // Paired doors make the overhead train-car shape recognizable.
    for (final x in [.28, .72]) {
      for (final y in [car.top, car.bottom - 8]) {
        final door = Rect.fromLTWH(size.width * x - 20, y, 40, 8);
        canvas.drawRRect(
          RRect.fromRectAndRadius(door, const Radius.circular(3)),
          Paint()..color = const Color(0xffc1cede),
        );
        canvas.drawLine(
          Offset(door.center.dx, door.top),
          Offset(door.center.dx, door.bottom),
          outline,
        );
      }
    }
    for (final x in [.1, .44, .84]) {
      for (final y in [23.0, size.height - 35]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * x, y, size.width * .12, 12),
            const Radius.circular(4),
          ),
          Paint()..color = const Color(0xffd2e2f3),
        );
      }
    }
    if (value == null) return;
    final count = value == 0
        ? 0
        : math.max(1, (value!.clamp(0, 200) / 200 * 80).round());
    final area = Rect.fromLTRB(24, 46, size.width - 24, size.height - 46);
    final cellW = area.width / 16, cellH = area.height / 5;
    final unit = math.min(cellW / 1.3, cellH / 2.5);
    final paint = Paint()..color = crowdColor(value!);
    for (var n = 0; n < count; n++) {
      final i = n * 37 % 80;
      final center = Offset(
        area.left + (i % 16 + .5) * cellW,
        area.top + (i ~/ 16 + .5) * cellH,
      );
      canvas.drawCircle(center.translate(0, -unit * .85), unit * .36, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center.translate(0, unit * .1),
            width: unit * .75,
            height: unit * 1.05,
          ),
          Radius.circular(unit * .25),
        ),
        paint,
      );
      final limb = Paint()
        ..color = paint.color
        ..strokeWidth = unit * .22
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center.translate(-unit * .38, -unit * .2),
        center.translate(-unit * .6, unit * .48),
        limb,
      );
      canvas.drawLine(
        center.translate(unit * .38, -unit * .2),
        center.translate(unit * .6, unit * .48),
        limb,
      );
      for (final side in [-1, 1]) {
        canvas.drawLine(
          center.translate(side * unit * .19, unit * .5),
          center.translate(side * unit * .26, unit * 1.15),
          limb,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CrowdCarriagePainter oldDelegate) =>
      oldDelegate.value != value;
}
