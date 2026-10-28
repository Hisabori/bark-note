import 'package:flutter/material.dart';
import 'crowd_data.dart';
import 'crowd_timeline.dart';
import 'planner.dart';

class CrowdPanel extends StatefulWidget {
  const CrowdPanel({
    super.key,
    required this.station,
    required this.line,
    required this.direction,
    required this.now,
    required this.walk,
  });
  final String station, line, direction;
  final DateTime now;
  final int walk;
  @override
  State<CrowdPanel> createState() => _CrowdPanelState();
}

class _CrowdPanelState extends State<CrowdPanel> {
  final future = CrowdData.load();
  String? lineOverride, directionOverride, dayOverride;
  @override
  void didUpdateWidget(CrowdPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.station != widget.station ||
        oldWidget.line != widget.line ||
        oldWidget.direction != widget.direction) {
      lineOverride = null;
      directionOverride = null;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '평소 얼마나 붐빌까?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text('공식 30분 평균 통계 · 실시간 열차 혼잡도나 좌석 보장은 아닙니다.'),
          FutureBuilder<CrowdData>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  '통계를 불러오지 못했습니다. 앱을 다시 열어주세요. 서버 주소는 필요하지 않습니다.',
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              if (widget.walk < 0) return const Text('올바른 승강장 도보시간을 입력해주세요.');
              final data = snapshot.data!;
              final clock = seoulClock(widget.now);
              final day =
                  dayOverride ??
                  (clock.weekday == 6
                      ? '토요일'
                      : clock.weekday == 7
                      ? '일요일'
                      : '평일');
              final line =
                  lineOverride ??
                  (RegExp(r'^100[1-9]$').hasMatch(widget.line)
                      ? '${int.parse(widget.line) - 1000}호선'
                      : widget.line.isEmpty
                      ? '1호선'
                      : '선택 노선 (${widget.line})');
              final stationRows = data.forStation(widget.station, line);
              final directions =
                  stationRows.map((p) => p.direction).toSet().toList()..sort();
              final requestedDirection =
                  directionOverride ?? crowdDirection(widget.direction);
              final direction = directions.contains(requestedDirection)
                  ? requestedDirection
                  : null;
              final matching = stationRows
                  .where((p) => p.day == day && p.direction == direction)
                  .toList();
              final profile = matching.length == 1 ? matching.first : null;
              final board = seoulClock(
                widget.now.add(Duration(minutes: widget.walk + 1)),
              );
              final sameDate =
                  board.year == clock.year &&
                  board.month == clock.month &&
                  board.day == clock.day;
              final minute = (board.hour * 60 + board.minute) ~/ 30 * 30;
              final value = sameDate ? profile?.slots[minute] : null;
              final later =
                  profile?.slots.entries
                      .where(
                        (e) =>
                            sameDate && e.key > minute && e.key <= minute + 120,
                      )
                      .toList() ??
                  [];
              later.sort(
                (a, b) => a.value == b.value
                    ? a.key.compareTo(b.key)
                    : a.value.compareTo(b.value),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.station.isEmpty ? '출발역을 입력해주세요' : widget.station} · 기준일 ${data.asOf}',
                  ),
                  Wrap(
                    spacing: 12,
                    children: [
                      DropdownButton<String>(
                        value: line,
                        items: {...List.generate(8, (i) => '${i + 1}호선'), line}
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() {
                          lineOverride = v;
                          directionOverride = null;
                        }),
                      ),
                      DropdownButton<String>(
                        value: day,
                        items: ['평일', '토요일', '일요일']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => dayOverride = v),
                      ),
                      if (directions.isNotEmpty)
                        DropdownButton<String>(
                          value: direction,
                          hint: const Text('통계 방향 선택'),
                          items: directions
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => directionOverride = v),
                        ),
                    ],
                  ),
                  const Text('공휴일은 일요일 통계를 직접 선택해주세요.'),
                  if (stationRows.isEmpty)
                    const Text(
                      '이 역·노선은 공식 통계 제공 구간이 아닙니다. 서울교통공사 1~8호선의 제공 역만 조회됩니다.',
                    )
                  else if (direction == null)
                    const Text('방향을 선택하면 혼잡도가 표시됩니다.')
                  else if (value == null)
                    const Text('예상 승강장 도착 시간대의 통계가 없습니다. 없는 값을 0%로 표시하지 않습니다.')
                  else
                    Text(
                      '탑승 시간대 평균 ${value.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (value != null)
                    Text(
                      '${board.hour.toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')} 시간대 · 도보 ${widget.walk}분 + 여유 1분 반영',
                    ),
                  if (value != null && later.any((e) => e.value < value)) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '이후 2시간 중 더 여유로운 시간대',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  if (value != null)
                    ...later
                        .where((e) => e.value < value)
                        .take(3)
                        .map(
                          (e) => Text(
                            '${(e.key ~/ 60).toString().padLeft(2, '0')}:${(e.key % 60).toString().padLeft(2, '0')} 탑승 시간대 평균 ${e.value.toStringAsFixed(1)}% · 현재 시간대보다 낮음',
                          ),
                        ),
                  if (profile != null)
                    CrowdTimeline(
                      key: ValueKey(
                        '${profile.station}|${profile.line}|${profile.day}|${profile.direction}',
                      ),
                      slots: profile.slots,
                      boardMinute: sameDate ? minute : -1,
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    '출처: 서울교통공사 · 공공데이터포털 15071311. 정원 대비 승차인원 비율이며, 좌석만 모두 차면 약 34%입니다.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
