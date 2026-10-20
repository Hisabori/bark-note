import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'planner.dart';
import 'transit_api.dart';
import 'live_plan.dart';
import 'kakao_panel.dart';

void main() => runApp(const RailApp());

class RailApp extends StatelessWidget {
  const RailApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '나갈때',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff20695c)),
      scaffoldBackgroundColor: const Color(0xfff4f6f3),
    ),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static const alerts = MethodChannel('com.railtime/alerts');
  final station = TextEditingController(),
      destination = TextEditingController(),
      kakaoKey = TextEditingController(
        text: const String.fromEnvironment('KAKAO_REST_API_KEY'),
      ),
      apiKey = TextEditingController(
        text: const String.fromEnvironment('SEOUL_API_KEY'),
      );
  final fields = List.generate(5, (_) => TextEditingController());
  final labels = ['출발지 → 승강장', '열차 이동 + 환승', '예상 열차 대기', '도착역 → 목적지', '추가 여유'];
  int tab = 0;
  bool confirmed = false, loading = false;
  String message = '';
  String arrivalDirection = '전체', selectedTrain = '';
  DateTime deadline = DateTime.now().toUtc().add(const Duration(minutes: 90));
  List<Map<String, dynamic>> arrivals = [];
  Timer? timer;
  DateTime? reminder;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 5; i++) {
      fields[i].text = ['10', '30', '5', '5', '5'][i];
    }
    load();
    loadReminder();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<File> prefs() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/rail-time.json');
  Future<void> load() async {
    try {
      final f = await prefs();
      if (!await f.exists()) {
        return;
      }
      final p = jsonDecode(await f.readAsString()) as Map;
      station.text = p['station'] as String? ?? '';
      destination.text = p['destination'] as String? ?? '';
      server.text = p['server'] as String? ?? '';
      apiKey.text = p['apiKey'] as String? ?? apiKey.text;
      kakaoKey.text = p['kakaoKey'] as String? ?? kakaoKey.text;
      line.text = p['line'] as String? ?? '';
      direction.text = p['direction'] as String? ?? '';
      selectedTrain = p['selectedTrain'] as String? ?? '';
      final savedDeadline = DateTime.tryParse(p['deadline'] as String? ?? '');
      if (savedDeadline != null && savedDeadline.isAfter(DateTime.now())) {
        deadline = savedDeadline;
      }
      final values = p['minutes'];
      if (values is List && values.length == 5) {
        for (int i = 0; i < 5; i++) {
          fields[i].text = values[i].toString();
        }
      }
      if (mounted) {
        setState(() {
          confirmed =
              p['confirmed'] == true &&
              savedDeadline != null &&
              savedDeadline.isAfter(DateTime.now()) &&
              station.text.trim().isNotEmpty &&
              destination.text.trim().isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = '이전 설정을 읽지 못했습니다. 다시 입력해주세요.');
      }
    }
  }

  Future<void> save() async {
    final f = await prefs();
    await f.writeAsString(
      jsonEncode({
        'station': station.text,
        'destination': destination.text,
        'server': server.text,
        'apiKey': apiKey.text,
        'kakaoKey': kakaoKey.text,
        'line': line.text,
        'direction': direction.text,
        'selectedTrain': selectedTrain,
        'confirmed': confirmed,
        'deadline': deadline.toUtc().toIso8601String(),
        'minutes': fields.map((c) => c.text).toList(),
      }),
      flush: true,
    );
  }

  Journey? get journey {
    final nums = fields.map((c) => int.tryParse(c.text)).toList();
    if (!confirmed ||
        nums.any((n) => n == null || n < 0 || n > 240) ||
        nums[1] == 0) {
      return null;
    }
    return Journey(
      deadline: deadline,
      walkToPlatform: nums[0]!,
      rideAndTransfer: nums[1]!,
      wait: nums[2]!,
      exitWalk: nums[3]!,
      buffer: nums[4]!,
    );
  }

  void fail(Object error) {
    if (mounted) {
      setState(
        () => message = error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('FormatException: ', ''),
      );
    }
  }

  Future<void> targetTime() async {
    final clock = seoulClock(deadline);
    final now = seoulClock(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: clock.isBefore(now) ? now : clock,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 30)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: clock.hour, minute: clock.minute),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      deadline = seoulInstant(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    await cancelReminder();
    try {
      await save();
    } catch (e) {
      fail(e);
    }
  }

  Future<void> editPlan() async {
    final controllers = [station, destination, ...fields];
    final before = controllers.map((c) => c.text).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('내 이동시간 설정'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '자동 길찾기 전 단계입니다. 평소 걸리는 시간을 직접 입력해주세요. 기본값은 실제 경로 정보가 아닙니다.',
                ),
                TextField(
                  controller: station,
                  decoration: const InputDecoration(labelText: '출발역 (예: 강남)'),
                ),
                TextField(
                  controller: destination,
                  decoration: const InputDecoration(labelText: '목적지'),
                ),
                for (int i = 0; i < 5; i++)
                  TextField(
                    controller: fields[i],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: labels[i],
                      suffixText: '분',
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('이 시간으로 계산'),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    if (ok != true) {
      for (int i = 0; i < controllers.length; i++) {
        controllers[i].text = before[i];
      }
      return;
    }
    await cancelReminder();
    setState(() {
      confirmed =
          ok == true &&
          station.text.trim().isNotEmpty &&
          destination.text.trim().isNotEmpty;
      arrivals = [];
      selectedTrain = '';
      generation++;
    });
    if (ok == true) {
      if (journey == null) {
        fail('역·목적지와 0~240분의 이동시간을 확인해주세요. 열차 이동은 1분 이상이어야 합니다.');
      } else {
        try {
          await save();
        } catch (e) {
          fail(e);
        }
      }
    }
  }

  Future<void> fetchArrivals() async {
    if (loading) {
      return;
    }
    if (apiKey.text.trim().isEmpty) {
      fail('설정에서 서울시 지하철 인증키를 입력해주세요.');
      return;
    }
    if (station.text.trim().isEmpty) {
      fail('먼저 출발역을 입력해주세요.');
      return;
    }
    final token = ++generation;
    setState(() {
      loading = true;
      message = '';
      arrivals = [];
    });
    try {
      final value = await directArrivals(apiKey.text, station.text);
      if (mounted && token == generation) {
        setState(
          () => arrivals = (value['arrivals'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
        if (arrivals.isEmpty) {
          fail('현재 도착정보가 없습니다. 운행 종료 여부를 확인해주세요.');
        }
      }
    } catch (e) {
      fail(e);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> cancelReminder() async {
    try {
      await alerts.invokeMethod('cancel');
      if (mounted) {
        setState(() => reminder = null);
      }
    } catch (e) {
      fail('기존 알림 취소를 확인하지 못했습니다: $e');
    }
  }

  Future<void> loadReminder() async {
    try {
      final epoch = await alerts.invokeMethod<num>('status');
      if (mounted &&
          epoch != null &&
          epoch > DateTime.now().millisecondsSinceEpoch) {
        setState(
          () => reminder = DateTime.fromMillisecondsSinceEpoch(
            epoch.toInt(),
            isUtc: true,
          ),
        );
      }
    } catch (_) {
      /* Native status is optional while previewing the UI. */
    }
  }

  Future<void> schedule(DateTime time, {String? basis}) async {
    if (!time.isAfter(DateTime.now().toUtc())) {
      fail('이미 지난 출발 시각입니다. 목표 시각을 변경해주세요.');
      return;
    }
    try {
      final granted = await alerts.invokeMethod<bool>('schedule', {
        'epoch': time.millisecondsSinceEpoch,
        'title': '이제 나갈 시간이에요',
        'body': basis ?? '입력한 이동시간 기준으로 출발할 시간입니다.',
      });
      if (granted != true) {
        fail('알림 권한이 허용되지 않았습니다. 기기 설정을 확인해주세요.');
        return;
      }
      if (mounted) {
        setState(() => reminder = time);
      }
    } catch (e) {
      fail('알림을 예약하지 못했습니다. $e');
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final c in [station, destination, apiKey, kakaoKey, ...fields]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget card(Widget child) => Card(
    elevation: 0,
    color: Colors.white,
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
  Widget title(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      value,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final plan = journey;
    final now = DateTime.now().toUtc();
    return Scaffold(
      appBar: AppBar(
        title: const Text('나갈때'),
        actions: [
          IconButton(
            onPressed: editPlan,
            icon: const Icon(Icons.edit_location_alt_outlined),
            tooltip: '이동 계획 입력',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.schedule), label: '출발 플랜'),
          NavigationDestination(
            icon: Icon(Icons.train_outlined),
            label: '실시간 열차',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: '설정'),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            if (loading) const LinearProgressIndicator(),
            if (message.isNotEmpty)
              card(
                Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (tab == 0) ...[
              const Text(
                '길을 찾고,\n제때 출발해요.',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title('나갈 시간'),
                    if (plan == null) ...[
                      const Text('출발역·목적지와 평소 이동시간을 입력해 첫 플랜을 만들어보세요.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: editPlan,
                        icon: const Icon(Icons.add),
                        label: const Text('이동 계획 만들기'),
                      ),
                    ] else ...[
                      Text('${station.text} → ${destination.text}'),
                      Text(
                        hm(plan.leaveAt),
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff20695c),
                        ),
                      ),
                      Text(
                        plan.leaveAt.isBefore(now)
                            ? '권장 출발 시각이 지났습니다. 이동 계획을 확인해주세요.'
                            : '약 ${plan.leaveAt.difference(now).inMinutes}분 뒤 출발',
                      ),
                      const SizedBox(height: 10),
                      const Text('입력한 이동시간 기준 · 운행 지연/막차/환승 가능 여부는 반영하지 않습니다.'),
                      const Divider(height: 28),
                      Text('목표 도착 ${hm(deadline)} · 총 ${plan.total}분'),
                      Text(
                        '도보 ${plan.walkToPlatform} + 이동/환승 ${plan.rideAndTransfer} + 대기 ${plan.wait} + 도착 도보 ${plan.exitWalk} + 여유 ${plan.buffer}분',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: targetTime,
                            child: const Text('목표 도착 변경'),
                          ),
                          FilledButton.icon(
                            onPressed: () => schedule(plan.leaveAt),
                            icon: const Icon(Icons.notifications_outlined),
                            label: const Text('출발 알림 예약'),
                          ),
                        ],
                      ),
                    ],
                    if (reminder != null) ...[
                      const Divider(),
                      Text('${hm(reminder!)} 출발 알림 예약됨 · 시스템에 따라 지연될 수 있습니다.'),
                      TextButton(
                        onPressed: cancelReminder,
                        child: const Text('알림 취소'),
                      ),
                    ],
                  ],
                ),
              ),
              KakaoPanel(
                apiKey: kakaoKey.text,
                deadline: deadline,
                buffer: int.tryParse(fields[4].text) ?? 5,
                onTime: targetTime,
                onAlarm: (time) => schedule(time, basis: '카카오 경로 조회 소요시간 기준'),
              ),
            ],
            if (tab == 0 && plan != null) liveCard(plan, now),
            if (tab == 1) ...[
              title('지금 오는 열차'),
              TextField(
                controller: station,
                decoration: const InputDecoration(
                  labelText: '조회할 역 이름',
                  hintText: '서울, 강남 등 (역 접미사 제외)',
                ),
                onChanged: (_) => setState(() {
                  arrivals = [];
                  selectedTrain = '';
                  generation++;
                  confirmed = false;
                }),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: loading ? null : fetchArrivals,
                icon: const Icon(Icons.refresh),
                label: const Text('실시간 도착정보 조회'),
              ),
              if (arrivals.isEmpty)
                card(
                  const Text(
                    '아직 조회된 열차가 없습니다. 서버 미연결이나 제공기관 오류일 때 도착정보를 만들어 표시하지 않습니다.',
                  ),
                ),
              if (arrivals.isNotEmpty) ...[
                const Text('출발 계획에 사용할 노선·방향을 열차 카드에서 선택하세요.'),
                Wrap(
                  spacing: 6,
                  children:
                      {'전체', ...arrivals.map((e) => e['direction'] as String)}
                          .map(
                            (v) => ChoiceChip(
                              label: Text(v),
                              selected: arrivalDirection == v,
                              onSelected: (_) =>
                                  setState(() => arrivalDirection = v),
                            ),
                          )
                          .toList(),
                ),
                ...arrivals
                    .where(
                      (a) =>
                          arrivalDirection == '전체' ||
                          a['direction'] == arrivalDirection,
                    )
                    .map((a) {
                      final t = DateTime.tryParse(a['eta'] as String? ?? '');
                      final received = DateTime.tryParse(
                        a['receivedAt'] as String? ?? '',
                      );
                      final fresh =
                          received != null &&
                          now.difference(received).inSeconds <= 120 &&
                          a['fresh'] == true;
                      final seconds = t?.difference(now).inSeconds;
                      return card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_lineName(a['line'].toString())} · ${a['direction']}',
                            ),
                            Text(
                              a['destination'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              fresh && seconds != null && seconds > 0
                                  ? '약 ${seconds ~/ 60}분 ${seconds % 60}초 뒤'
                                  : a['message'].toString(),
                              style: const TextStyle(fontSize: 24),
                            ),
                            Text(
                              received == null
                                  ? '정보 시각 미제공'
                                  : '제공기관 갱신 ${hm(received)}${fresh ? '' : ' · 오래된 정보 (예상시각 사용 안 함)'}',
                            ),
                            const Text(
                              '종착역·급행 여부를 확인하고 탑승해주세요.',
                              style: TextStyle(fontSize: 12),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                setState(() {
                                  selectedTrain =
                                      '${a['line']}|${a['direction']}|${a['terminal']}';
                                  tab = 0;
                                });
                                try {
                                  await save();
                                } catch (e) {
                                  fail(e);
                                }
                              },
                              icon: const Icon(Icons.route),
                              label: const Text('이 노선·방향으로 출발 계산'),
                            ),
                          ],
                        ),
                      );
                    }),
              ],
            ],
            if (tab == 2) ...[
              title('휴대폰에서 직접 조회'),
              TextField(
                controller: apiKey,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: '서울시 지하철 인증키'),
              ),
              const Text(
                '실시간 열차는 휴대폰에서 서울시 API로 직접 조회합니다. 인터넷 연결이 필요합니다. 인증키는 이 기기에 저장됩니다. 카카오 경로도 휴대폰에서 직접 조회합니다.',
              ),
              TextField(
                controller: kakaoKey,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: '카카오 REST API 키'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    await cancelReminder();
                    await save();
                    if (mounted) {
                      setState(() {
                        arrivals = [];
                        generation++;
                        message = '설정을 저장했습니다.';
                      });
                    }
                  } catch (e) {
                    fail(e);
                  }
                },
                child: const Text('설정 저장'),
              ),
              card(
                const Text(
                  '지원 범위\n\n수도권 데이터 연결용 첫 버전입니다. 실제 제공 범위는 운영기관 API에 따릅니다.\n\n출발 계산: 직접 입력한 이동시간 기준\n경로 조회: 카카오 API 현재 응답 기준\n칸별 실시간 혼잡도·막차 보장: 제공하지 않습니다.\n\n출발 알림은 저장한 시각의 로컬 알림이며 실시간 운행을 백그라운드에서 재조회하지 않습니다.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget liveCard(Journey plan, DateTime now) {
    final matching = arrivals
        .where(
          (a) =>
              '${a['line']}|${a['direction']}|${a['terminal']}' ==
              selectedTrain,
        )
        .toList();
    matching.sort(
      (a, b) =>
          (a['eta'] as String? ?? 'z').compareTo(b['eta'] as String? ?? 'z'),
    );
    final candidates = matching
        .map((a) => livePlan(a, plan, now))
        .whereType<LivePlan>()
        .where((p) => p.canCatch)
        .toList();
    final chosen = candidates.isEmpty ? null : candidates.first;
    final selected = selectedTrain.split('|');
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title('지금 나가면 탈 수 있을까?'),
          if (selectedTrain.isEmpty)
            const Text('실시간 열차에서 탈 노선·방향·종착역을 선택해주세요.')
          else ...[
            Text(
              '${_lineName(selected.first)} · ${selected[1]} · ${selected[2]}행',
            ),
            if (chosen == null)
              const Text('현재 걸어서 탈 수 있는 열차 예측이 없습니다. 새로 조회하거나 다음 열차를 확인해주세요.')
            else ...[
              Text(
                '${hm(chosen.leaveAt)}까지 출발',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '약 ${chosen.leaveAt.difference(now).inSeconds ~/ 60}분 뒤 출발 · 예상 도착 ${hm(chosen.arriveAt)}',
              ),
              Text(
                chosen.onTime
                    ? '입력한 여유시간을 포함해 목표 도착 가능'
                    : '이 열차는 목표 도착 여유가 부족합니다.',
              ),
            ],
          ],
          const SizedBox(height: 8),
          const Text(
            '승강장 도보 + 탑승 여유 1분 반영. 이동·환승 시간은 직접 입력한 값이며, 종착역 이후 경로와 급행 정차 여부는 직접 확인해주세요.',
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: loading ? null : fetchArrivals,
                icon: const Icon(Icons.refresh),
                label: const Text('현재 열차로 다시 계산'),
              ),
              TextButton(
                onPressed: () => setState(() => tab = 1),
                child: const Text('탈 열차 선택'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _lineName(String value) =>
      const {
        '1001': '1호선',
        '1002': '2호선',
        '1003': '3호선',
        '1004': '4호선',
        '1005': '5호선',
        '1006': '6호선',
        '1007': '7호선',
        '1008': '8호선',
        '1009': '9호선',
        '1065': '공항철도',
        '1075': '수인분당선',
        '1077': '신분당선',
        '1063': '경의중앙선',
        '1067': '경춘선',
      }[value] ??
      '노선 $value';
}
