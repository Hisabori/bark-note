import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'app_theme.dart';
import 'local_store.dart';
import 'bark_report.dart';
import 'breed.dart';

class BarkHistoryPage extends StatefulWidget {
  const BarkHistoryPage({super.key});
  @override
  State<BarkHistoryPage> createState() => _BarkHistoryPageState();
}

class _BarkHistoryPageState extends State<BarkHistoryPage> {
  String query = '';
  late final Future<List<Map<String, dynamic>>> records = load();
  Future<List<Map<String, dynamic>>> load() async {
    final store = JsonSnapshotStore(
      file: () async => File(
        '${(await getApplicationDocumentsDirectory()).path}/history.json',
      ),
      accepts: (value) => value is List,
    );
    final value = await store.read();
    return value is List
        ? value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : [];
  }

  void openRecord(Map<String, dynamic> audio) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('분석 기록')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  '${audio['dog'] ?? '우리 강아지'}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${audio['date'] ?? ''}'),
                const SizedBox(height: 20),
                BarkPatternReport(audio: audio),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('당시 메모\n${audio['note'] ?? ''}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('지난 분석')),
    body: SafeArea(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: records,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('기록을 읽지 못했습니다. 원본은 그대로 보존됩니다. 앱을 다시 열어 확인해주세요.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final visible = all
              .where(
                (e) =>
                    '${e['dog']} ${breedLabel(e['breed'])} ${e['note']} ${e['date']}'
                        .toLowerCase()
                        .contains(query.toLowerCase()),
              )
              .toList();
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: visible.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CareIntro(
                      label: '기록에서 발견하는 흐름',
                      title: '우리 강아지의\n지난 소리를 모아봐요.',
                      subtitle: '이름·품종·상황 메모로 찾아보고 분석 근거를 다시 확인해요.',
                      icon: Icons.history_rounded,
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          '저장된 분석 ${all.length}개 · AI 확인 기록 ${all.where((e) => e['ai'] is Map && e['aiError'] == null).length}개',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: '이름, 품종, 메모, 날짜 검색',
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }
              if (index == 1) {
                return visible.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('표시할 분석 기록이 없어요.'),
                      )
                    : const SizedBox.shrink();
              }
              final audio = visible[index - 2];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: const Icon(
                    Icons.graphic_eq_rounded,
                    color: Color(0xff17a89c),
                  ),
                  title: Text(
                    '${audio['dog'] ?? '우리 강아지'} · ${breedLabel(audio['breed'])}',
                  ),
                  subtitle: Text(
                    '${audio['date'] ?? ''}\n${audio['note'] ?? ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => openRecord(audio),
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
