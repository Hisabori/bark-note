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
import 'crowd_panel.dart';
import 'saved_route.dart';

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
  List<SavedRoute> savedRoutes = [];
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
      final saved = p['savedRoutes'];
      if (saved is List) {
        savedRoutes = saved
            .map(SavedRoute.parse)
            .whereType<SavedRoute>()
            .take(20)
            .toList();
      }
      station.text = p['station'] as String? ?? '';
      destination.text = p['destination'] as String? ?? '';
      apiKey.text = p['apiKey'] as String? ?? apiKey.text;
      kakaoKey.text = p['kakaoKey'] as String? ?? kakaoKey.text;
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
        'apiKey': apiKey.text,
        'kakaoKey': kakaoKey.text,
        'selectedTrain': selectedTrain,
        'confirmed': confirmed,
        'deadline': deadline.toUtc().toIso8601String(),
        'minutes': fields.map((c) => c.text).toList(),
        'savedRoutes': savedRoutes.map((r) => r.toJson()).toList(),
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

  Future<void> saveRoute() async {
    final plan = journey;
    if (plan == null) {
      setState(() => message = '먼저 출발 계획의 역·목적지·이동시간을 확정해주세요.');
      return;
    }
    final name = TextEditingController(
      text: '${station.text} → ${destination.text}',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('자주 가는 경로 저장'),
        content: TextField(
          controller: name,
          maxLength: 40,
          decoration: const InputDecoration(labelText: '경로 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(context, name.text.trim());
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    // The dialog route may still be animating while its text field is mounted.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    if (!mounted || result == null) return;
    final clock = seoulClock(deadline);
    setState(() {
      savedRoutes.removeWhere((r) => r.name == result);
      savedRoutes.insert(
        0,
        SavedRoute(
          result,
          station.text.trim(),
          destination.text.trim(),
          selectedTrain,
          fields.map((c) => int.parse(c.text)).toList(),
          clock.hour,
          clock.minute,
        ),
      );
      savedRoutes = savedRoutes.take(20).toList();
      message = '경로를 저장했습니다. 같은 이름으로 저장하면 갱신됩니다.';
    });
    try {
      await save();
    } catch (e) {
      fail(e);
    }
  }

  Future<void> applyRoute(SavedRoute route) async {
    generation++;
    await cancelReminder();
    if (!mounted) return;
    setState(() {
      station.text = route.station;
      destination.text = route.destination;
      selectedTrain = route.train;
      for (var i = 0; i < 5; i++) {
        fields[i].text = '${route.minutes[i]}';
      }
      deadline = route.nextDeadline(DateTime.now().toUtc());
      confirmed = true;
      arrivals = [];
      loading = false;
      arrivalDirection = '전체';
      message = '${route.name} 경로를 불러왔습니다. 도착 날짜와 시각을 확인하고 열차를 새로 조회하세요.';
    });
    try {
      await save();
    } catch (e) {
      fail(e);
    }
  }

  Widget savedRouteCard() => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '자주 가는 경로',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: saveRoute,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('현재 계획 저장'),
            ),
          ],
        ),
        if (savedRoutes.isEmpty)
          const Text('확정한 출발 계획을 저장하면 다음에도 바로 불러올 수 있어요.'),
        for (final route in savedRoutes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bookmark_outline),
            title: Text(route.name),
            subtitle: Text(
              '${route.station} → ${route.destination} · 도착 ${route.hour.toString().padLeft(2, '0')}:${route.minute.toString().padLeft(2, '0')}',
            ),
            onTap: () => applyRoute(route),
            trailing: IconButton(
              tooltip: '저장 경로 삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                setState(() => savedRoutes.remove(route));
                try {
                  await save();
                } catch (e) {
                  fail(e);
                }
              },
            ),
          ),
        if (savedRoutes.isNotEmpty)
          const Text('오늘 시각이 지났으면 내일로 설정됩니다. 알림과 열차 정보는 새로 설정하세요.'),
      ],
    ),
  );

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
              KakaoPanel(
                apiKey: kakaoKey.text,
                deadline: deadline,
                buffer: int.tryParse(fields[4].text) ?? 5,
                onTime: targetTime,
                onJourneyChanged: cancelReminder,
                onAlarm: (time) => schedule(time, basis: '카카오 경로 조회 소요시간 기준'),
              ),
              savedRouteCard(),
              liveCard(plan, now),
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
              CrowdPanel(
                station: station.text,
                line: selectedTrain.split('|').first,
                direction: selectedTrain.split('|').length > 1
                    ? selectedTrain.split('|')[1]
                    : '',
                now: now,
                walk:
                    ((int.tryParse(fields[0].text) ?? -1) >= 0 &&
                        (int.tryParse(fields[0].text) ?? -1) <= 240)
                    ? int.parse(fields[0].text)
                    : -1,
              ),
            ],

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
                card(const Text('아직 조회된 열차가 없습니다. 인터넷 연결과 인증키를 확인한 뒤 조회해주세요.')),
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

  Future<void> showActivity(
    BoardingEstimate estimate,
    Map<String, dynamic> train,
  ) async {
    try {
      final received = DateTime.parse(train['receivedAt'] as String);
      final ok = await alerts.invokeMethod<bool>('liveStart', {
        'station': station.text.trim(),
        'train':
            '${_lineName(train['line'].toString())} ${train['direction']} ${train['terminal']}행',
        'leaveEpoch': estimate.leaveBy.millisecondsSinceEpoch,
        'trainEpoch': estimate.eta.millisecondsSinceEpoch,
        'staleEpoch': received
            .add(const Duration(seconds: 120))
            .millisecondsSinceEpoch,
      });
      if (ok != true) {
        fail('실시간 현황을 사용할 수 없습니다. iOS 16.2 이상과 실시간 현황 권한을 확인해주세요.');
      }
    } catch (_) {
      fail('실시간 현황을 시작하지 못했습니다. 기기 설정을 확인해주세요.');
    }
  }

  Widget liveCard(Journey? plan, DateTime now) {
    final groups = <String, Map<String, dynamic>>{};
    for (final train in arrivals) {
      groups['${train['line']}|${train['direction']}|${train['terminal']}'] =
          train;
    }
    final walk = int.tryParse(fields[0].text);
    final matching =
        arrivals
            .where(
              (a) =>
                  '${a['line']}|${a['direction']}|${a['terminal']}' ==
                  selectedTrain,
            )
            .toList()
          ..sort(
            (a, b) => (a['eta'] as String? ?? 'z').compareTo(
              b['eta'] as String? ?? 'z',
            ),
          );
    final usable = <MapEntry<Map<String, dynamic>, BoardingEstimate>>[];
    if (walk != null) {
      for (final train in matching) {
        final estimate = boardingEstimate(train, walk, now);
        if (estimate != null) usable.add(MapEntry(train, estimate));
      }
    }
    final catchable = usable.where((e) => e.value.canCatch).toList();
    final chosen = catchable.isEmpty ? null : catchable.first;
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title('지금 나가면 탈 수 있을까?'),
          const Text(
            '출발역과 승강장까지 걸리는 시간을 입력하고 탈 노선·방향을 선택하세요. 목적지 입력 없이 탑승 가능 여부를 확인할 수 있습니다.',
          ),
          TextField(
            controller: station,
            decoration: const InputDecoration(labelText: '출발역'),
            onChanged: (_) => setState(() {
              arrivals = [];
              selectedTrain = '';
              confirmed = false;
              generation++;
            }),
          ),
          TextField(
            controller: fields[0],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '지금 위치 → 승강장',
              suffixText: '분',
            ),
            onChanged: (_) {
              setState(() {});
            },
          ),
          OutlinedButton.icon(
            onPressed: loading ? null : fetchArrivals,
            icon: const Icon(Icons.refresh),
            label: const Text('실시간 열차 조회·다시 계산'),
          ),
          if (groups.isNotEmpty)
            DropdownButton<String>(
              isExpanded: true,
              value: groups.containsKey(selectedTrain) ? selectedTrain : null,
              hint: const Text('탈 노선·방향·종착역 선택'),
              items: groups.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        '${_lineName(e.value['line'].toString())} · ${e.value['direction']} · ${e.value['terminal']}행',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) async {
                if (v != null) {
                  setState(() => selectedTrain = v);
                  try {
                    await save();
                  } catch (e) {
                    fail(e);
                  }
                }
              },
            ),
          if (walk == null || walk < 0 || walk > 240)
            const Text('도보시간은 0~240분으로 입력해주세요.'),
          if (selectedTrain.isNotEmpty && usable.isEmpty)
            const Text(
              '계산 가능한 최신 도착예측이 없습니다. 2분이 지난 정보나 도착 시각이 없는 열차는 다시 조회해주세요.',
            ),
          for (final entry in usable.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                entry.value.canCatch
                    ? Icons.check_circle_outline
                    : Icons.directions_walk,
                color: entry.value.canCatch ? Colors.green : Colors.orange,
              ),
              title: Text(
                entry.value.canCatch ? '지금 출발하면 탑승 가능 예상' : '이 열차는 도보시간이 부족해요',
              ),
              subtitle: Text(
                '열차 ${hm(entry.value.eta)} · 승강장 준비 ${hm(entry.value.readyAt)}\n${entry.value.canCatch ? '탑승 여유' : '부족한 시간'} ${(entry.value.spareSeconds.abs() / 60).ceil()}분',
              ),
              isThreeLine: true,
            ),
          if (chosen != null) ...[
            Text(
              '${hm(chosen.value.leaveBy)}까지 출발',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            if (plan != null)
              Text(
                '입력한 이동시간 기준 예상 도착 ${hm(chosen.value.eta.add(Duration(minutes: plan.rideAndTransfer + plan.exitWalk)))}',
              ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: chosen.value.leaveBy.isAfter(now)
                      ? () => schedule(
                          chosen.value.leaveBy,
                          basis: '선택한 열차 예측 기준입니다. 운행 변동은 앱에서 확인해주세요.',
                        )
                      : null,
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('이 열차 출발 알림'),
                ),
                if (Platform.isIOS)
                  OutlinedButton.icon(
                    onPressed: () => showActivity(chosen.value, chosen.key),
                    icon: const Icon(Icons.phone_iphone),
                    label: const Text('다이내믹 아일랜드에 표시'),
                  ),
              ],
            ),
          ],
          if (Platform.isIOS)
            TextButton(
              onPressed: () async {
                try {
                  await alerts.invokeMethod('liveEnd');
                } catch (_) {
                  fail('실시간 현황을 종료하지 못했습니다.');
                }
              },
              child: const Text('실시간 현황 종료'),
            ),
          const Text(
            '승강장 도보 + 탑승 여유 1분을 반영한 예측입니다. 종착역·급행 정차 여부는 확인해주세요. 실시간 현황은 마지막 조회 예측의 카운트다운이며 앱 종료 후 운행정보를 새로 조회하지 않습니다.',
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
