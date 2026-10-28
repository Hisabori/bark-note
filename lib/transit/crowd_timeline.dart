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
            aspectRatio: 1.6,
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
          '통계 평균을 한 객차의 밀집 모습으로 표현한 예시입니다. 실제 인원·칸별 혼잡도·좌석 보장을 뜻하지 않으며, 통계가 없으면 물음표로 표시합니다.',
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

/// Perspective view from inside the carriage, drawn locally with vector shapes.
class CrowdCarriagePainter extends CustomPainter {
  CrowdCarriagePainter(this.value);
  final double? value;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 720, size.height / 450);
    void polygon(List<Offset> points, Color color) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, Paint()..color = color);
    }

    void line(Offset a, Offset b, Color color, [double width = 2]) {
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    void box(Rect rect, Color color, [double radius = 8]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()..color = color,
      );
    }

    Offset point(double u, double depth, [double height = 0]) => Offset(
      360 + u * (120 + 240 * depth),
      250 + 190 * depth - height * (.48 + .75 * depth),
    );
    polygon([
      const Offset(0, 0),
      const Offset(720, 0),
      const Offset(480, 70),
      const Offset(240, 70),
    ], const Color(0xfff3f5f7));
    polygon([
      const Offset(0, 0),
      const Offset(240, 70),
      const Offset(240, 250),
      const Offset(0, 450),
    ], const Color(0xffe4ebf0));
    polygon([
      const Offset(720, 0),
      const Offset(480, 70),
      const Offset(480, 250),
      const Offset(720, 450),
    ], const Color(0xffe4ebf0));
    box(const Rect.fromLTWH(240, 70, 240, 180), const Color(0xffd9e2e9), 0);
    polygon([
      const Offset(240, 250),
      const Offset(480, 250),
      const Offset(720, 450),
      const Offset(0, 450),
    ], const Color(0xffd1dce4));
    polygon([
      point(-.50, 0),
      point(.50, 0),
      point(.50, 1),
      point(-.50, 1),
    ], const Color(0xffe5ecf1));
    for (final side in [-1.0, 1.0]) {
      // Long side windows and blue bench seats lead towards the rear doors.
      polygon([
        point(side, .07, 240),
        point(side, .95, 240),
        point(side, .95, 110),
        point(side, .07, 110),
      ], const Color(0xffb8d7e8));
      for (final t in [.08, .32, .57, .82]) {
        line(
          point(side, t, 245),
          point(side, t, 105),
          const Color(0xffa2b4c2),
          4,
        );
      }
      polygon([
        point(side * .69, .04, 53),
        point(side * .69, 1, 53),
        point(side, 1, 53),
        point(side, .04, 53),
      ], const Color(0xff8bb5d6));
      polygon([
        point(side * .69, .04, 53),
        point(side * .69, 1, 53),
        point(side * .69, 1, 18),
        point(side * .69, .04, 18),
      ], const Color(0xff679cc5));
      for (final t in [.10, .25, .40, .55, .70, .85]) {
        line(
          point(side * .71, t, 54),
          point(side * .98, t, 54),
          const Color(0xffb1cee4),
          2,
        );
      }
      line(
        point(side * .58, 0, 320),
        point(side * .58, 1, 320),
        const Color(0xff98aab9),
        5,
      );
      for (final t in [.18, .44, .70, .94]) {
        final top = point(side * .58, t, 320),
            bottom = point(side * .58, t, 281);
        line(top, bottom, const Color(0xff879baa), 2);
        final w = 8 + 7 * t;
        final path = Path()
          ..moveTo(bottom.dx, bottom.dy)
          ..lineTo(bottom.dx - w, bottom.dy + 13)
          ..lineTo(bottom.dx + w, bottom.dy + 13)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xff8298a9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
    box(const Rect.fromLTWH(294, 99, 132, 151), const Color(0xffa1b4c2), 9);
    box(const Rect.fromLTWH(299, 104, 57, 139), const Color(0xffe8eef2), 4);
    box(const Rect.fromLTWH(364, 104, 57, 139), const Color(0xffe8eef2), 4);
    box(const Rect.fromLTWH(306, 113, 42, 65), const Color(0xffa7cddd), 5);
    box(const Rect.fromLTWH(372, 113, 42, 65), const Color(0xffa7cddd), 5);
    line(
      const Offset(350, 190),
      const Offset(350, 220),
      const Color(0xff879baa),
      3,
    );
    line(
      const Offset(370, 190),
      const Offset(370, 220),
      const Color(0xff879baa),
      3,
    );
    box(const Rect.fromLTWH(320, 78, 80, 13), const Color(0xff458680), 3);
    // Ceiling lights, rails and seams make this read as a train interior.
    for (final side in [-1.0, 1.0]) {
      line(
        Offset(360 + side * 84, 45),
        Offset(360 + side * 225, 8),
        Colors.white,
        9,
      );
      line(
        point(side * .53, .22, 0),
        point(side * .53, .22, 275),
        const Color(0xff92a9b9),
        4,
      );
    }
    if (value != null) {
      final passengers = <({double u, double z, bool seated, int color})>[];
      final seated = value == 0
          ? 0
          : math.max(1, (value!.clamp(0, 34) / 34 * 12).round());
      for (var i = 0; i < seated; i++) {
        passengers.add((
          u: i.isEven ? -.78 : .78,
          z: .12 + (i ~/ 2) * .145,
          seated: true,
          color: i,
        ));
      }
      final standing = ((value!.clamp(34, 200) - 34) / 166 * 42).round();
      for (var i = 0; i < standing; i++) {
        final cell = i * 17 % 42;
        passengers.add((
          u: (cell % 7 - 3) * .135,
          z: .08 + (cell ~/ 7) * .17,
          seated: false,
          color: i + 5,
        ));
      }
      passengers.sort((a, b) => a.z.compareTo(b.z));
      const clothes = [
        Color(0xff477a97),
        Color(0xff528d88),
        Color(0xffb88570),
        Color(0xff817ca2),
        Color(0xff62778a),
      ];
      for (final person in passengers) {
        final foot = point(person.u, person.z, person.seated ? 16 : 0);
        final unit = 8 + person.z * 15;
        final body = clothes[person.color % clothes.length];
        canvas.drawOval(
          Rect.fromCenter(
            center: foot.translate(0, 2),
            width: unit * 1.7,
            height: unit * .40,
          ),
          Paint()..color = const Color(0x208099aa),
        );
        final head = foot.translate(0, -unit * (person.seated ? 3.15 : 4.2));
        canvas.drawCircle(
          head,
          unit * .46,
          Paint()..color = const Color(0xffd9b59a),
        );
        canvas.drawArc(
          Rect.fromCircle(
            center: head.translate(0, -unit * .1),
            radius: unit * .48,
          ),
          math.pi,
          math.pi,
          true,
          Paint()..color = const Color(0xff485462),
        );
        box(
          Rect.fromCenter(
            center: foot.translate(0, -unit * (person.seated ? 1.95 : 2.9)),
            width: unit * 1.25,
            height: unit * 1.8,
          ),
          body,
          unit * .30,
        );
        for (final side in [-1, 1]) {
          line(
            foot.translate(
              side * unit * .60,
              -unit * (person.seated ? 2.6 : 3.5),
            ),
            foot.translate(
              side * unit * .82,
              -unit * (person.seated ? 1.2 : 1.9),
            ),
            body,
            unit * .30,
          );
          line(
            foot.translate(
              side * unit * .30,
              -unit * (person.seated ? 1.1 : 2),
            ),
            foot.translate(side * unit * .40, 0),
            const Color(0xff495e70),
            unit * .35,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CrowdCarriagePainter oldDelegate) =>
      oldDelegate.value != value;
}
