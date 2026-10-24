import 'app_theme.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'analyzer.dart';
import 'emotion.dart';
import 'bark_model.dart';
import 'bark_result.dart';
import 'bark_insights.dart';
import 'breed.dart';

class BarkApp extends StatelessWidget {
  const BarkApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Bark Note',
    theme: buildAppTheme(),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  final recorder = AudioRecorder();
  final note = TextEditingController();
  final dog = TextEditingController(text: '우리 강아지');
  List<Map<String, dynamic>> history = [];
  Map<String, dynamic>? result;
  String emotionContext = 'unknown';
  String breed = 'unknown';
  bool recording = false, busy = false;
  int seconds = 0;
  Timer? timer;
  String? recordingPath;
  String status = '조용한 곳에서 강아지 가까이에 놓아주세요.';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && recording) {
      stop();
    }
  }

  Future<File> store() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/history.json');
  Future<void> load() async {
    try {
      final f = await store();
      if (await f.exists()) {
        final h = (jsonDecode(await f.readAsString()) as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (mounted) {
          setState(() {
            history = h;
            if (h.isNotEmpty) {
              dog.text = h.first['dog'] as String? ?? '우리 강아지';
              breed = normalizeBreed(h.first['breed']);
            }
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => status = '이전 기록을 읽지 못했습니다. 새 분석은 가능합니다.');
      }
    }
  }

  Future<void> persist() async {
    final f = await store();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(history), flush: true);
    await tmp.rename(f.path);
  }

  void error(Object e) {
    if (mounted) {
      setState(() {
        busy = false;
        status = e.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  Future<void> start() async {
    setState(() => busy = true);
    try {
      if (!await recorder.hasPermission()) {
        throw Exception('설정에서 마이크 사용 권한을 허용해주세요.');
      }
      recordingPath =
          '${(await getTemporaryDirectory()).path}/bark-${DateTime.now().millisecondsSinceEpoch}.wav';
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: recordingPath!,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        recording = true;
        busy = false;
        seconds = 0;
        status = '녹음 중 · 최대 60초';
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }
        setState(() => seconds++);
        if (seconds >= 60) {
          stop();
        }
      });
    } catch (e) {
      error(e);
    }
  }

  Future<void> stop() async {
    if (!recording || busy) {
      return;
    }
    timer?.cancel();
    setState(() {
      busy = true;
      recording = false;
    });
    try {
      final path = await recorder.stop();
      if (path == null) {
        throw Exception('녹음 파일을 찾지 못했습니다.');
      }
      await analyze(path, '직접 녹음');
    } catch (e) {
      error(e);
    } finally {
      final p = recordingPath;
      if (p != null && await File(p).exists()) {
        await File(p).delete();
      }
    }
  }

  Future<void> pick() async {
    setState(() => busy = true);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['wav'],
      );
      if (picked != null && picked.path != null) {
        await analyze(picked.path!, picked.name);
      }
    } catch (e) {
      error(e);
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> analyze(String path, String name) async {
    final f = File(path);
    if (await f.length() > 60 * 1024 * 1024) {
      throw const FormatException('60 MB 이하 WAV 파일을 선택해주세요.');
    }
    final bytes = await f.readAsBytes();
    final r = await compute(analyzeWav, bytes);
    if (mounted) {
      setState(() => status = '사전학습 AI로 소리 종류를 분석하고 있어요…');
    }
    try {
      final model = await rootBundle.load('assets/models/yamnet.tflite');
      final ai = await compute(classifyBarks, {
        'audio': bytes,
        'model': model.buffer.asUint8List(
          model.offsetInBytes,
          model.lengthInBytes,
        ),
      });
      applyBarkVerification(r, ai);
    } catch (_) {
      r['aiError'] =
          'AI 분석을 완료하지 못했습니다. 아래 횟수는 소리 크기로 찾은 후보이며 강아지 짖음 확인 결과가 아닙니다.';
    }
    r['dog'] = dog.text.trim().isEmpty ? '우리 강아지' : dog.text.trim();
    r['breed'] = breed;
    r['name'] = name;
    r['date'] = DateTime.now().toIso8601String();
    r['note'] = '';
    r['emotion'] = interpretEmotion(r, 'unknown');
    if (mounted) {
      setState(() {
        result = r;
        emotionContext = 'unknown';
        note.clear();
        busy = false;
        status = r['aiError'] == null
            ? '분석 완료 · 사전학습 YAMNet 적용'
            : '기본 분석 완료 · AI 분석 실패';
      });
    }
  }

  Future<void> save() async {
    if (result == null || busy || recording) {
      return;
    }
    setState(() => busy = true);
    final entry = {
      ...result!,
      'dog': dog.text.trim().isEmpty ? '우리 강아지' : dog.text.trim(),
      'breed': breed,
      'note': note.text.trim(),
      'emotion': interpretEmotion(result!, emotionContext),
    }..remove('levels');
    final old = [...history];
    setState(() {
      history.removeWhere((e) => e['date'] == entry['date']);
      history.insert(0, entry);
    });
    try {
      await persist();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('기록을 저장했습니다.')));
      }
    } catch (e) {
      if (mounted) setState(() => history = old);
      error(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    recorder.dispose();
    note.dispose();
    dog.dispose();
    super.dispose();
  }

  Widget panel(Widget child) => Card(
    elevation: 0,
    color: Colors.white,
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
  Widget metric(String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title),
      Text(
        value,
        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Bark Note'),
      backgroundColor: Colors.transparent,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            '우리 강아지의\n소리를 기록해요.',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          const Text('소리의 패턴을 살펴보고, 당시 상황을 함께 남겨보세요.'),
          const SizedBox(height: 20),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: dog,
                  maxLength: 40,
                  enabled: !busy && !recording,
                  decoration: const InputDecoration(labelText: '강아지 이름'),
                  onChanged: (_) => setState(() {}),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('breed-$breed'),
                  initialValue: breed,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '품종'),
                  items: dogBreeds.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: busy || recording
                      ? null
                      : (value) {
                          if (value != null) setState(() => breed = value);
                        },
                ),
                const SizedBox(height: 8),
                const Text(
                  '직접 선택한 품종으로 기록을 구분합니다. 소리로 품종을 추측하거나 품종만으로 감정을 판단하지 않습니다.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  recording ? Icons.graphic_eq : Icons.pets,
                  size: 56,
                  color: const Color(0xff296b56),
                ),
                const SizedBox(height: 16),
                Text(
                  recording ? '$seconds초 녹음 중' : '소리 분석 시작',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : recording
                      ? stop
                      : start,
                  icon: Icon(recording ? Icons.stop : Icons.mic),
                  label: Text(recording ? '녹음 종료 & 분석' : '60초 녹음하기'),
                ),
                OutlinedButton.icon(
                  onPressed: busy || recording ? null : pick,
                  icon: const Icon(Icons.audio_file),
                  label: const Text('WAV 파일 가져오기'),
                ),
                if (busy) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(status, textAlign: TextAlign.center),
              ],
            ),
          ),
          if (result != null)
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '분석 결과',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  emotionPanel(),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      metric('소리 크기 후보', '${result!['count']}회'),
                      if (result!['verifiedCount'] != null)
                        metric('AI 짖음 후보', '${result!['verifiedCount']}회'),
                      metric(
                        '전체 길이',
                        '${(result!['duration'] as num).toStringAsFixed(1)}초',
                      ),
                      metric(
                        '분당 후보',
                        (result!['perMinute'] as num).toStringAsFixed(1),
                      ),
                      metric(
                        '최대 프레임 음량',
                        '${(result!['peak'] as num).toStringAsFixed(1)} dBFS',
                      ),
                    ],
                  ),
                  if (result!['levels'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: SizedBox(
                        height: 90,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: WavePainter(
                            List<double>.from(result!['levels']),
                            (result!['threshold'] as num).toDouble(),
                          ),
                        ),
                      ),
                    ),
                  const Text('초록색: 음량 기준을 넘은 소리 · AI 확인 여부와는 별개입니다.'),
                  const SizedBox(height: 12),
                  aiPanel(),
                  insightsPanel(),
                  const SizedBox(height: 12),
                  Text(
                    (result!['count'] as int) == 0
                        ? '짖음 후보가 감지되지 않았습니다. 거리나 주변 소음을 확인해보세요.'
                        : '짧은 소리가 ${result!['count']}회 감지되었습니다. 당시 상황과 함께 확인해주세요.',
                  ),
                  const Divider(height: 28),
                  ...((result!['segments'] as List)
                      .take(30)
                      .map(
                        (s) => Text(
                          '${(s['start'] as num).toStringAsFixed(2)}초 — ${(s['end'] as num).toStringAsFixed(2)}초',
                        ),
                      )),
                  if ((result!['segments'] as List).length > 30)
                    const Text('처음 30구간만 표시합니다. 전체 구간은 기록에 저장됩니다.'),
                  TextField(
                    controller: note,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '상황 메모',
                      hintText: '예: 초인종이 울렸을 때, 산책 전',
                    ),
                  ),
                  FilledButton(
                    onPressed: busy || recording ? null : save,
                    child: const Text('이 분석 저장하기'),
                  ),
                ],
              ),
            ),
          panel(
            const Text(
              '분석 안내\n\n사전학습된 Google YAMNet으로 소리 종류를 분석합니다. AI 짖음 후보는 음량으로 찾은 구간 중 모델의 짖음 점수가 기준을 넘은 구간입니다. 약 1초 단위의 분석이라 다른 소리가 섞이거나 조용한 짖음을 놓칠 수 있습니다. 감정 학습 모델은 포함하지 않습니다. 감정 번역은 상황 기반 추정입니다. 모델은 기기에 포함되어 녹음을 서버에 보내지 않습니다.',
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '지난 기록',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('저장된 기록이 없습니다.'),
            ),
          ...history.asMap().entries.map(
            (e) => Card(
              child: ListTile(
                title: Text(
                  '${e.value['dog'] ?? '우리 강아지'} · ${e.value['verifiedCount'] != null ? 'AI 후보 ${e.value['verifiedCount']}' : '음량 후보 ${e.value['count']}'}회',
                ),
                subtitle: Text(
                  '${breedLabel(e.value['breed'])} · ${e.value['date'].toString().substring(0, 16).replaceAll('T', ' ')}\n${e.value['note']}',
                ),
                isThreeLine: true,
                onTap: recording || busy
                    ? null
                    : () => setState(() {
                        result = {...e.value};
                        final saved = e.value['emotion'];
                        emotionContext =
                            saved is Map &&
                                emotionContexts.containsKey(saved['context'])
                            ? saved['context'] as String
                            : 'unknown';
                        note.text = e.value['note'] as String? ?? '';
                        dog.text = e.value['dog'] as String? ?? '우리 강아지';
                        breed = normalizeBreed(e.value['breed']);
                      }),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: busy || recording
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('이 기록을 삭제할까요?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('취소'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('삭제'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true && mounted) {
                            final old = [...history];
                            setState(() => history.removeAt(e.key));
                            try {
                              await persist();
                            } catch (err) {
                              setState(() => history = old);
                              error(err);
                            }
                          }
                        },
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget insightsPanel() {
    final advice = recordingAdvice(result!);
    final comparison = compareBarkHistory(
      result!,
      history,
      dog.text,
      emotionContext,
      breed: breed,
    );
    final breedComparison = compareBarkHistory(
      result!,
      history,
      dog.text,
      emotionContext,
      breed: breed,
      sameDog: false,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '녹음 상태와 이전 기록',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (result!['quality'] == null)
            const Text('이전 버전 기록에는 녹음 상태 정보가 없습니다.')
          else if (advice.isEmpty)
            const Text('짧은 녹음·과도한 무음·입력 한계 경고가 없습니다. 분석 정확도를 보장하는 검사는 아닙니다.'),
          for (final item in advice) Text('• $item'),
          const SizedBox(height: 8),
          if (comparison == null)
            const Text('10초 이상 AI 분석 기록이 있으면 같은 이름·품종·상황의 최근 기록 최대 5개와 비교합니다.')
          else ...[
            Text(
              '분당 AI 짖음 후보: 이번 ${comparison.current.toStringAsFixed(1)}회 · 이전 ${comparison.previous.toStringAsFixed(1)}회',
            ),
            Text(
              '같은 강아지·품종·상황의 이전 ${comparison.records}개 기록을 녹음 길이로 가중해 비교했습니다. 녹음 거리와 주변 소음이 다르면 직접 비교하기 어렵습니다.',
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '${breedLabel(breed)} · 기기 내 품종별 비교',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (!canGroupBreed(breed))
            const Text('믹스견·기타·품종 모름은 서로 다른 품종을 묶지 않고 개별 기록만 비교합니다.')
          else if (breedComparison == null)
            const Text('이 기기에 같은 품종·상황의 이전 AI 분석 기록이 더 필요합니다.')
          else
            Text(
              '이 기기의 같은 품종 최근 ${breedComparison.records}개: 분당 AI 후보 ${breedComparison.previous.toStringAsFixed(1)}회. 품종 전체의 정상 범위나 감정 기준이 아닙니다.',
            ),
        ],
      ),
    );
  }

  Widget emotionPanel() {
    final interpretation = interpretEmotion(result!, emotionContext);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffedf4ef),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '감정 번역 · 추정',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('당시 상황을 선택해주세요'),
          Wrap(
            spacing: 6,
            children: emotionContexts.entries
                .map(
                  (e) => ChoiceChip(
                    label: Text(e.value),
                    selected: emotionContext == e.key,
                    onSelected: busy || recording
                        ? null
                        : (_) => setState(() => emotionContext = e.key),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Text(
            interpretation['label'] as String,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '“${interpretation['phrase']}”',
            style: const TextStyle(fontSize: 23, height: 1.5),
          ),
          const Text('이 문장은 가능한 상태를 쉽게 표현한 예시입니다.'),
          const SizedBox(height: 12),
          if ((interpretation['alternatives'] as List).isNotEmpty)
            Text(
              '다른 가능성: ${(interpretation['alternatives'] as List).join(' / ')}',
            ),
          const SizedBox(height: 8),
          ...((interpretation['reasons'] as List).map((r) => Text('• $r'))),
          const SizedBox(height: 8),
          Text(interpretation['observe'] as String),
          const SizedBox(height: 8),
          Text(interpretation['certainty'] as String),
        ],
      ),
    );
  }

  Widget aiPanel() {
    final ai = result!['ai'];
    if (ai is! Map) {
      return Text(
        result!['aiError'] as String? ??
            '이 기록은 AI 모델 적용 전 분석입니다. 새로 녹음하거나 파일을 다시 분석해주세요.',
      );
    }
    String score(String key) => (ai[key] as num).toStringAsFixed(3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '사전학습 AI · Google YAMNet',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          '최대 모델 점수: 짖음 ${score('barkPeak')} / 강아지 소리 ${score('dogPeak')} / 말소리 ${score('speechPeak')}',
        ),
        const Text(
          '0–1의 모델 점수이며 정확도·감정 확률이 아닙니다. AI 짖음 후보 기준: 구간 가중 평균 0.30 이상(미보정).',
        ),
        if ((result!['verifiedCount'] as int? ?? 0) == 0)
          const Text('AI가 뒷받침하는 짖음 후보가 없습니다. 감정 해석을 보류합니다.'),
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  WavePainter(this.levels, this.threshold);
  final List<double> levels;
  final double threshold;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..strokeWidth = 2;
    for (int x = 0; x < size.width.toInt(); x += 3) {
      final v =
          levels[(x / size.width * levels.length).floor().clamp(
            0,
            levels.length - 1,
          )];
      p.color = v > threshold
          ? const Color(0xff296b56)
          : const Color(0xffcbd5cd);
      final h = ((v + 60) / 60).clamp(.03, 1) * size.height;
      canvas.drawLine(
        Offset(x.toDouble(), (size.height - h) / 2),
        Offset(x.toDouble(), (size.height + h) / 2),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) =>
      oldDelegate.levels != levels;
}
