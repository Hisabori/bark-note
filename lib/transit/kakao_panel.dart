import 'package:flutter/material.dart';
import 'kakao_api.dart';
import 'planner.dart';
import 'route_map.dart';

class KakaoPanel extends StatefulWidget {
  const KakaoPanel({
    super.key,
    required this.apiKey,
    required this.deadline,
    required this.buffer,
    required this.onTime,
    required this.onAlarm,
  });
  final String apiKey;
  final DateTime deadline;
  final int buffer;
  final VoidCallback onTime;
  final Future<void> Function(DateTime) onAlarm;
  @override
  State<KakaoPanel> createState() => _KakaoPanelState();
}

class _KakaoPanelState extends State<KakaoPanel> {
  KakaoPlace? start, end;
  List<KakaoRoute> routes = [];
  String message = '';
  bool loading = false;
  String filter = '전체';
  KakaoRoute? selected;
  int generation = 0;
  List<KakaoRoute> get visible => routes
      .where(
        (r) =>
            filter == '전체' ||
            (filter == '버스 포함' ? r.hasBus : r.type == 'SUBWAY'),
      )
      .toList();
  DateTime? fetched;

  Future<void> choose(bool origin) async {
    final query = TextEditingController();
    List<KakaoPlace> places = [];
    String error = '';
    bool busy = false;
    final place = await showDialog<KakaoPlace>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          Future<void> search() async {
            if (busy) return;
            update(() {
              busy = true;
              error = '';
              places = [];
            });
            try {
              final result = await KakaoApi(widget.apiKey).search(query.text);
              if (ctx.mounted) {
                update(() {
                  places = result;
                  if (result.isEmpty) error = '검색 결과가 없습니다.';
                });
              }
            } catch (e) {
              if (ctx.mounted) {
                update(
                  () => error = e.toString().replaceFirst('Bad state: ', ''),
                );
              }
            } finally {
              if (ctx.mounted) update(() => busy = false);
            }
          }

          return AlertDialog(
            title: Text(origin ? '출발 장소 검색' : '도착 장소 검색'),
            content: SizedBox(
              width: 420,
              height: 360,
              child: Column(
                children: [
                  TextField(
                    controller: query,
                    decoration: const InputDecoration(hintText: '역·건물·장소 이름'),
                    onSubmitted: (_) => search(),
                  ),
                  TextButton(
                    onPressed: busy ? null : search,
                    child: const Text('카카오 장소 검색'),
                  ),
                  if (busy) const LinearProgressIndicator(),
                  if (error.isNotEmpty) Text(error),
                  Expanded(
                    child: ListView(
                      children: places
                          .map(
                            (p) => ListTile(
                              title: Text(p.name),
                              subtitle: Text(p.address),
                              onTap: () => Navigator.pop(ctx, p),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('닫기'),
              ),
            ],
          );
        },
      ),
    );
    // The dialog's route may still be animating; its controller is collected
    // with the route rather than disposed while a TextField is attached.
    if (place != null && mounted) {
      setState(() {
        if (origin) {
          start = place;
        } else {
          end = place;
        }
        routes = [];
        selected = null;
        generation++;
        message = '';
        fetched = null;
      });
    }
  }

  Future<void> searchRoutes() async {
    if (start == null || end == null || loading) return;
    setState(() {
      loading = true;
      message = '';
      routes = [];
      selected = null;
      fetched = null;
    });
    final token = ++generation;
    try {
      final result = await KakaoApi(widget.apiKey).routes(start!, end!);
      if (mounted && token == generation) {
        setState(() {
          routes = result;
          selected = visible.firstOrNull;
          fetched = DateTime.now().toUtc();
          if (result.isEmpty) message = '조회 가능한 경로가 없습니다.';
        });
      }
    } catch (e) {
      if (mounted && token == generation) {
        setState(() => message = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted && token == generation) setState(() => loading = false);
    }
  }

  @override
  void didUpdateWidget(KakaoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiKey != widget.apiKey) {
      routes = [];
      selected = null;
      generation++;
      loading = false;
      fetched = null;
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
            '버스·지하철 경로 지도',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text('카카오 API로 직접 검색합니다. 혼잡도·좌석 정보는 제공하지 않습니다.'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(start?.name ?? '출발 장소 선택'),
            subtitle: start == null ? null : Text(start!.address),
            trailing: const Icon(Icons.search),
            onTap: loading ? null : () => choose(true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(end?.name ?? '도착 장소 선택'),
            subtitle: end == null ? null : Text(end!.address),
            trailing: const Icon(Icons.search),
            onTap: loading ? null : () => choose(false),
          ),
          Text('목표 도착 ${hm(widget.deadline)} · 추가 여유 ${widget.buffer}분'),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: loading || start == null || end == null
                    ? null
                    : searchRoutes,
                child: const Text('경로·출발 시각 조회'),
              ),
              TextButton(
                onPressed: widget.onTime,
                child: const Text('목표 시각 변경'),
              ),
            ],
          ),
          if (loading) const LinearProgressIndicator(),
          if (message.isNotEmpty) Text(message),
          if (fetched != null) Text('카카오맵 제공 · 조회 ${hm(fetched!)}'),
          if (routes.isNotEmpty)
            Wrap(
              spacing: 8,
              children: ['전체', '버스 포함', '지하철만']
                  .map(
                    (value) => ChoiceChip(
                      label: Text(value),
                      selected: filter == value,
                      onSelected: (_) => setState(() {
                        filter = value;
                        selected = visible.firstOrNull;
                      }),
                    ),
                  )
                  .toList(),
            ),
          if (routes.isNotEmpty && visible.isEmpty)
            const Text('이 조건에 맞는 경로가 없습니다. 다른 이동수단을 선택해주세요.'),
          if (selected != null && start != null && end != null)
            RouteMap(
              key: ObjectKey(selected),
              route: selected!,
              start: start!,
              end: end!,
              apiKey: widget.apiKey,
            ),
          ...visible.map((r) {
            final leave = r.leaveBy(widget.deadline, widget.buffer);
            return ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: Icon(
                r.hasBus ? Icons.directions_bus : Icons.subway,
                color: selected == r
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text('${r.label} · ${r.minutes}분 · 환승 ${r.transfers}회'),
              onExpansionChanged: (open) {
                if (open) setState(() => selected = r);
              },
              subtitle: Text(
                '${hm(leave)} 출발 권장${leave.isBefore(DateTime.now().toUtc()) ? ' · 출발 시각 지남' : ''}',
              ),
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => selected = r),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('이 경로를 지도에 표시'),
                ),
                for (final step in r.guidance)
                  ListTile(dense: true, title: Text(step)),
                TextButton.icon(
                  onPressed: leave.isAfter(DateTime.now().toUtc())
                      ? () => widget.onAlarm(leave)
                      : null,
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('이 경로 출발 알림'),
                ),
              ],
            );
          }),
          const Text(
            '현재 조회된 경로 소요시간 + 추가 여유 기준입니다. 미래 시간표·막차·지연·탑승 가능성을 보장하지 않습니다. 실시간 열차 출발 계산과는 별도 경로입니다.',
          ),
        ],
      ),
    ),
  );
}
