import 'app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'bark_home.dart' as bark;
import 'transit/main.dart' as transit;

void main() {
  runApp(const BarkApp());
  if (const bool.fromEnvironment('STARTUP_SMOKE')) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await const MethodChannel(
        'com.railtime/alerts',
      ).invokeMethod('startupReady');
    });
  }
}

class BarkApp extends StatelessWidget {
  const BarkApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Bark Note',
    theme: buildAppTheme(),
    darkTheme: buildAppTheme(brightness: Brightness.dark),
    themeMode: ThemeMode.system,
    home: const FeatureHome(),
  );
}

class FeatureHome extends StatelessWidget {
  const FeatureHome({super.key});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0, .48, 1],
        colors: Theme.of(context).brightness == Brightness.dark
            ? const [Color(0xff342039), Color(0xff1e1020), Color(0xff100c17)]
            : const [Color(0xffe0d8f2), Color(0xfff6e6df), Color(0xfff3f3f8)],
      ),
    ),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Bark Note'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  '${DateTime.now().month}월 ${DateTime.now().day}일 · 오늘도 함께',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '함께하는 하루',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '우리 강아지를 이해하고,\n외출은 여유 있게 준비해요.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 24),
                _feature(
                  context,
                  Icons.pets_rounded,
                  '강아지 소리 분석',
                  '소리와 상황을 함께 기록해요.',
                  '녹음 · 품종별 기록 · 이전 분석 비교',
                  const bark.Home(),
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xffa7e4d8)
                      : const Color(0xff138477),
                ),
                const SizedBox(height: 12),
                _feature(
                  context,
                  Icons.directions_transit_rounded,
                  '버스·지하철 · 나갈때',
                  '가는 길과 출발할 시간을 한눈에.',
                  '주변 지도 · 내 위치 · 경로 · 출발 알림',
                  const transit.Home(),
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xffc7b0ff)
                      : const Color(0xff387df5),
                ),
                const SizedBox(height: 20),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.phonelink_lock_outlined, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '소리 분석은 기기 안에서 처리해요. 교통 정보 조회에는 인터넷이 필요해요.',
                        style: TextStyle(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _feature(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    String detail,
    Widget page,
    Color color,
  ) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(icon, color: color, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle, style: const TextStyle(height: 1.4)),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12, left: 4),
                  child: Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              detail,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
