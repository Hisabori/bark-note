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
          .max(0, times.indexOf(initial ?? -1) * 64 - 64)
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
        if (mounted && scroll.hasClients)
          scroll.jumpTo(
            math
                .max(0, times.indexOf(initial ?? -1) * 64 - 64)
                .toDouble()
                .clamp(0, scroll.position.maxScrollExtent),
          );
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
    final maxValue = widget.slots.values.fold<double>(100, math.max);
    final ceiling = (maxValue / 50).ceil() * 50.0;
    final v = widget.slots[selected];
    final labelHeight = MediaQuery.textScalerOf(context).scale(14) * 1.6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Text(
          '시간대별 혼잡도',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '막대를 눌러 비교해요 · 그래프 상단 ${ceiling.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xfff2f6fc),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '${selected == null ? '' : crowdTime(selected!)} · ${v == null ? '통계 없음' : '평균 ${v.toStringAsFixed(1)}%'}${selected == widget.boardMinute ? ' · 예상 탑승 시간대' : ''}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 132 + labelHeight * 3,
          child: ListView.builder(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            itemCount: keys.length,
            itemExtent: 64,
            itemBuilder: (context, index) {
              final minute = keys[index];
              final value = widget.slots[minute];
              final active = selected == minute;
              final text =
                  '${crowdTime(minute)}, ${value == null ? '통계 없음' : '${value.toStringAsFixed(1)}퍼센트'}';
              return Semantics(
                button: true,
                selected: active,
                label: text,
                excludeSemantics: true,
                child: Tooltip(
                  message: text,
                  child: InkWell(
                    onTap: () => setState(() => selected = minute),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: active
                            ? const Color(0xffe8effc)
                            : Colors.transparent,
                        border: Border.all(
                          color: active
                              ? const Color(0xff387df5)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: labelHeight,
                            child: Center(
                              child: Text(
                                value == null ? '—' : value.toStringAsFixed(0),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 120,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: value == null
                                  ? const Text('—')
                                  : Container(
                                      width: 23,
                                      height: math.max(
                                        value == 0 ? 2 : 4,
                                        116 * value / ceiling,
                                      ),
                                      decoration: BoxDecoration(
                                        color: crowdColor(value),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(
                            height: labelHeight,
                            child: Center(
                              child: Text(
                                crowdTime(minute),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: labelHeight,
                            child: minute == widget.boardMinute
                                ? const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 14,
                                    color: Color(0xff387df5),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final item in [
              (0.0, '50% 미만'),
              (50.0, '50~100% 미만'),
              (100.0, '100% 이상'),
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 9, color: crowdColor(item.$1)),
                  const SizedBox(width: 5),
                  Text(item.$2, style: const TextStyle(fontSize: 12)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '색상은 비교를 위한 앱 표시 구간입니다. 좌우로 밀면 다른 시간대가 보이며, —는 미제공 값입니다.',
          style: TextStyle(fontSize: 12, height: 1.5),
        ),
      ],
    );
  }
}
