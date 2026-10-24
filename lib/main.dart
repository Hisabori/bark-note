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
    home: const FeatureHome(),
  );
}

class FeatureHome extends StatelessWidget {
  const FeatureHome({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bark Note')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text(
            '오늘 필요한 도구',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('강아지의 소리를 기록하고, 외출할 시간을 확인하세요.'),
          const SizedBox(height: 24),
          _feature(
            context,
            Icons.pets,
            '강아지 소리 분석',
            '소리를 녹음하고 상황과 함께 기록해요.',
            const bark.Home(),
          ),
          const SizedBox(height: 16),
          _feature(
            context,
            Icons.train_outlined,
            '버스·지하철 · 나갈때',
            '버스·지하철 경로와 출발할 시간을 확인해요.',
            const transit.Home(),
          ),
          const SizedBox(height: 20),
          const Text('소리 분석은 기기에서 처리합니다. 지하철 정보 조회에는 인터넷이 필요합니다.'),
        ],
      ),
    ),
  );

  Widget _feature(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget page,
  ) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(20),
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 28,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(subtitle),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => page)),
    ),
  );
}
