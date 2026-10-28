import 'app_theme.dart';
import 'bark_history.dart';
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
    themeMode: ThemeMode.light,
    home: const FeatureHome(),
  );
}

class FeatureHome extends StatelessWidget {
  const FeatureHome({super.key});
  void open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return CareSummarySurface(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            '요약',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          ),
          backgroundColor: Colors.transparent,
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(36),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0c172d48),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(36),
              child: NavigationBar(
                selectedIndex: 0,
                onDestinationSelected: (index) {
                  if (index == 1) open(context, const bark.Home());
                  if (index == 2) open(context, const transit.Home());
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: '오늘',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.pets_outlined),
                    label: '강아지',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.directions_transit_outlined),
                    label: '이동',
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  Text(
                    '${now.month}월 ${now.day}일 · 오늘도 함께',
                    style: TextStyle(color: muted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '함께하는 하루',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '소중한 일상, 조금 더 편안하게.',
                    style: TextStyle(fontSize: 17, color: muted, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '나에게 맞춘 오늘',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.favorite_border_rounded,
                                size: 22,
                                color: Color(0xff138477),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '강아지의 소리를 이해하고,\n외출은 여유 있게 준비해요.',
                                  style: TextStyle(
                                    fontSize: 17,
                                    height: 1.5,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    open(context, const bark.Home()),
                                icon: const Icon(Icons.mic_none_rounded),
                                label: const Text('소리 기록하기'),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    open(context, const transit.Home()),
                                icon: const Icon(Icons.near_me_outlined),
                                label: const Text('나갈 시간 확인'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '빠른 기록',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          constraints.maxWidth >= 350 &&
                              MediaQuery.textScalerOf(context).scale(14) <= 18
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: width,
                            child: _feature(
                              context,
                              Icons.pets_outlined,
                              '강아지 소리 분석',
                              '녹음 · 품종별 기록',
                              const bark.Home(),
                              const Color(0xff138477),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _feature(
                              context,
                              Icons.directions_transit_rounded,
                              '버스·지하철 · 나갈때',
                              '지도 · 경로 · 출발 알림',
                              const transit.Home(),
                              const Color(0xff387df5),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _feature(
                              context,
                              Icons.insights_outlined,
                              '지난 분석',
                              '기록과 패턴 돌아보기',
                              const BarkHistoryPage(),
                              const Color(0xff8c73d9),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _feature(
                              context,
                              Icons.train_outlined,
                              '실시간 열차',
                              '도착 정보 확인',
                              const transit.Home(initialTab: 1),
                              const Color(0xff17a89c),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.phonelink_lock_outlined,
                            color: Color(0xff138477),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '내 기기에서 안전하게',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '소리 분석은 기기 안에서 처리해요. 교통 정보 조회에는 인터넷이 필요해요.',
                                  style: TextStyle(color: muted, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _feature(
    BuildContext context,
    IconData icon,
    String title,
    String detail,
    Widget page,
    Color accent,
  ) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => open(context, page),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 100),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
