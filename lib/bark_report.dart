import 'package:flutter/material.dart';
import 'bark_patterns.dart';

class BarkPatternReport extends StatelessWidget {
  const BarkPatternReport({super.key, required this.audio});
  final Map<String, dynamic> audio;
  @override
  Widget build(BuildContext context) {
    final summary = summarizeBarkPatterns(audio);
    if (summary == null) return const Text('이 기록에는 패턴을 계산할 녹음 정보가 없습니다.');
    final quality = audio['quality'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xfff3f6fb),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '한눈에 보는 소리 패턴',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            summary.verified
                ? 'AI로 뒷받침된 짖음 후보 기준'
                : '음량으로 찾은 소리 후보 기준 · 짖음 확인 전',
            style: const TextStyle(color: Color(0xff657487), height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _metric('연속 후보 묶음', '${summary.bouts.length}개'),
              _metric(
                '후보 구간 총길이',
                '${summary.activeSeconds.toStringAsFixed(1)}초',
              ),
              _metric(
                '후보 사이 중앙 간격',
                summary.medianGap == null
                    ? '비교할 구간 없음'
                    : '${summary.medianGap!.toStringAsFixed(2)}초',
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final bout in summary.bouts.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    size: 19,
                    color: Color(0xff17a89c),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${bout.start.toStringAsFixed(1)}–${bout.end.toStringAsFixed(1)}초 · 후보 ${bout.count}회',
                    ),
                  ),
                ],
              ),
            ),
          if (summary.bouts.length > 6)
            Text('외 ${summary.bouts.length - 6}개 묶음 · 전체 구간은 상세 보기에서 확인해요.'),
          const Text(
            '1.5초 이내로 이어진 후보를 묶었습니다. 후보 길이는 겹치는 구간을 중복 계산하지 않으며 감정·건강 판정은 아닙니다.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xff657487),
              height: 1.5,
            ),
          ),
          if (quality is Map &&
              quality['noiseFloorDb'] is num &&
              quality['levelSpreadDb'] is num) ...[
            const SizedBox(height: 12),
            Text(
              '낮은 음량 구간 ${(quality['noiseFloorDb'] as num).toStringAsFixed(1)} dBFS · 프레임 음량 차이 ${(quality['levelSpreadDb'] as num).toStringAsFixed(1)} dB',
              style: const TextStyle(fontSize: 12, color: Color(0xff657487)),
            ),
            const Text(
              '전체 프레임의 20백분위와 90–20백분위 차이입니다. 기기 간 보정된 소음도나 정확도 점수가 아닙니다.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xff657487),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String title, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 12, color: Color(0xff657487)),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    ],
  );
}
