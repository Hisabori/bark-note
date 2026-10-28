import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'app_theme.dart';
import 'live_bark_core.dart';
import 'live_bark_worker.dart';

class RecordLiveMicrophone implements LiveMicrophone {
  final recorder = AudioRecorder();
  @override
  Future<bool> permission() => recorder.hasPermission();
  @override
  Future<Stream<Uint8List>> start() => recorder.startStream(
    const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      streamBufferSize: 3200,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    ),
  );
  @override
  Stream<bool> get interruptions => recorder.onStateChanged().map(
    (s) => s == RecordState.pause || s == RecordState.stop,
  );
  @override
  Future<void> stop() async {
    await recorder.stop();
  }

  @override
  Future<void> dispose() => recorder.dispose();
}

class LiveBarkPage extends StatefulWidget {
  const LiveBarkPage({super.key, this.microphoneFactory, this.scorerFactory});
  final LiveMicrophone Function()? microphoneFactory;
  final LiveBarkScorer Function()? scorerFactory;
  @override
  State<LiveBarkPage> createState() => _LiveBarkPageState();
}

class _LiveBarkPageState extends State<LiveBarkPage>
    with WidgetsBindingObserver {
  late final LiveBarkSession session;
  bool leaving = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session = LiveBarkSession(
      microphone: widget.microphoneFactory?.call() ?? RecordLiveMicrophone(),
      scorerFactory: widget.scorerFactory ?? LiveBarkWorker.new,
      changed: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(session.stop('앱이 뒤로 가서 마이크와 분석을 중지했습니다.'));
    }
  }

  Future<void> leave() async {
    if (leaving) return;
    leaving = true;
    await session.stop();
    await session.startup;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(session.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = session.latest;
    final stale =
        session.updated != null &&
        (DateTime.now().difference(session.updated!) >
                const Duration(seconds: 3) ||
            session.elapsed - session.latestEnd > 3);
    final active = session.running;
    final label = result == null
        ? (active ? '약 1초의 소리를 모으고 있어요' : '시작하면 현재 소리가 표시돼요')
        : stale && active
        ? '분석이 지연되고 있어요'
        : (result['bark'] as num) >= .3
        ? '짖음 소리 후보'
        : (result['dog'] as num) >= .3
        ? '강아지 소리 후보'
        : (result['speech'] as num) >= .3
        ? '말소리 반응'
        : '뚜렷한 짖음 반응 없음';
    final energy = ((session.level + 60) / 60).clamp(0.0, 1.0);
    return PopScope(
      canPop: !session.running && !session.opening && session.stopping == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(leave());
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('실시간 분석')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const CareIntro(
                label: '지금 들리는 소리',
                title: '듣는 동안,\n바로 확인해요.',
                subtitle: '녹음 파일 없이 기기 안에서 짖음 소리 후보를 살펴봐요.',
                icon: Icons.hearing_rounded,
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(
                            const Color(0xffeef3fb),
                            const Color(0xffadddd5),
                            active ? energy : 0,
                          ),
                        ),
                        child: Icon(
                          active
                              ? Icons.graphic_eq_rounded
                              : Icons.mic_none_rounded,
                          size: 48,
                          color: const Color(0xff138477),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        active ? '실시간' : '대기 / 최근 결과',
                        style: const TextStyle(color: Color(0xff657487)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(session.message, textAlign: TextAlign.center),
                      if (session.starting || session.stopping != null)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                session.unavailable ||
                                    session.running ||
                                    session.opening ||
                                    session.stopping != null
                                ? null
                                : () => unawaited(session.start()),
                            icon: const Icon(Icons.mic),
                            label: const Text('실시간 분석 시작'),
                          ),
                          OutlinedButton.icon(
                            onPressed: session.running || session.opening
                                ? () => unawaited(session.stop())
                                : null,
                            icon: const Icon(Icons.stop_rounded),
                            label: const Text('중지'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '실시간 분석 요약',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          metric(
                            '들어온 소리',
                            '${session.elapsed.toStringAsFixed(1)}초',
                          ),
                          metric('분석한 창', '${session.processed}개'),
                          metric('짖음 반응 창', '${session.positive}개'),
                          metric(
                            '현재 음량',
                            '${session.level.toStringAsFixed(1)} dBFS',
                          ),
                        ],
                      ),
                      if (result != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          '최근 입력 ${session.latestEnd.toStringAsFixed(1)}초 지점 · 모델 처리 ${(result['milliseconds'] as num).toStringAsFixed(0)}ms',
                        ),
                        Text(
                          '모델 점수 · 짖음 ${(result['bark'] as num).toStringAsFixed(3)} / 강아지 ${(result['dog'] as num).toStringAsFixed(3)} / 말소리 ${(result['speech'] as num).toStringAsFixed(3)}',
                        ),
                      ],
                      if (session.skipped > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '처리 지연으로 ${session.skipped}개 창을 건너뛰고 최신 입력을 우선했습니다.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '약 0.975초 창을 0.48초 간격으로 분석합니다. 창은 겹치므로 반응 창 수는 실제 짖은 횟수가 아닙니다. 점수 0.30 기준의 미보정 후보이며 감정 확률·정확도가 아닙니다.\n\n원음과 실시간 결과는 저장하거나 서버로 보내지 않습니다. 화면을 떠나거나 앱이 뒤로 가면 중지하며, 한 번에 최대 5분입니다. 기록을 남기려면 일반 녹음 분석을 사용해주세요.',
                    style: TextStyle(height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget metric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xff657487)),
      ),
      Text(
        value,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    ],
  );
}
