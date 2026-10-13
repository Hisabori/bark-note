/// Unvalidated, context-assisted interpretation; never a calibrated prediction.
const emotionContexts = <String, String>{
  'unknown': '상황 모름',
  'visitor': '초인종 / 낯선 사람',
  'play': '놀이 / 산책 준비',
  'alone': '혼자 있었음',
  'request': '밥 / 관심을 기다림',
};

Map<String, dynamic> interpretEmotion(
  Map<String, dynamic> audio,
  String context,
) {
  final segments = (audio['segments'] as List? ?? []).cast<Map>();
  Map<String, dynamic> output(
    String label,
    String phrase,
    List<String> alternatives,
    List<String> reasons,
    String observe,
  ) => {
    'version': 1,
    'context': context,
    'label': label,
    'phrase': phrase,
    'alternatives': alternatives,
    'reasons': reasons,
    'observe': observe,
    'certainty': '미검증 추정 · 정확도 수치 없음',
  };
  if (segments.length < 2) {
    return output('판단 보류', '해석할 소리가 충분하지 않아요.', [], [
      '짖음 후보가 2개 미만입니다.',
    ], '조용한 곳에서 여러 번 짖는 구간을 다시 녹음해주세요.');
  }
  final lengths = segments
      .map((s) => (s['end'] as num).toDouble() - (s['start'] as num).toDouble())
      .toList();
  final gaps = <double>[];
  for (int i = 1; i < segments.length; i++) {
    gaps.add(
      (segments[i]['start'] as num).toDouble() -
          (segments[i - 1]['end'] as num).toDouble(),
    );
  }
  final average = lengths.reduce((a, b) => a + b) / lengths.length;
  final gap = gaps.reduce((a, b) => a + b) / gaps.length;
  final reasons = <String>[
    '짖음 후보 ${segments.length}개 · 평균 길이 ${average.toStringAsFixed(2)}초',
    '후보 사이 평균 간격 ${gap.toStringAsFixed(2)}초',
    gap < .5
        ? '짧은 간격으로 반복되는 소리입니다. 이것만으로 긍정/부정 감정을 구별할 수 없습니다.'
        : '간격을 두고 반복되는 소리입니다. 이것만으로 감정을 구별할 수 없습니다.',
  ];
  if (!emotionContexts.containsKey(context) || context == 'unknown') {
    return output(
      '흥분 / 경계 / 요구 가능성',
      '무언가에 반응하고 있을 수 있어요.',
      ['놀이 중 흥분', '낯선 자극에 대한 경계', '관심이나 먹이를 요구'],
      reasons,
      '아래에서 당시 상황을 선택하고 꼬리·귀·몸의 긴장과 접근/회피 행동을 함께 살펴보세요.',
    );
  }
  reasons.add('사용자가 선택한 상황: ${emotionContexts[context]}. 해석은 이 입력에 크게 의존합니다.');
  switch (context) {
    case 'visitor':
      return output(
        '경계 / 긴장 가능성',
        '누가 왔어요. 신경 쓰여요!',
        ['반가움이나 흥분', '접근을 부담스러워함'],
        reasons,
        '몸이 굳는지, 뒤로 피하는지, 느슨하게 다가가는지 확인해주세요.',
      );
    case 'play':
      return output(
        '기대 / 놀이 흥분 가능성',
        '같이 놀아요! 빨리 가고 싶어요!',
        ['기다림에 대한 답답함', '자극이 부담스러움'],
        reasons,
        '느슨한 몸, 놀이 인사 자세와 자발적인 참여가 있는지 확인해주세요.',
      );
    case 'alone':
      return output(
        '불편함 / 접촉 요구 가능성',
        '혼자 있는 게 불편할 수도 있어요.',
        ['밖의 소리에 대한 경계', '지루함이나 관심 요구'],
        reasons,
        '주변 소리와 움직임도 확인해주세요. 짖음만으로 분리불안을 판단하지 않습니다.',
      );
    default:
      return output(
        '기대 / 관심 요구 가능성',
        '나도 봐주세요. 기다리고 있어요!',
        ['흥분', '기다림에 대한 답답함'],
        reasons,
        '어디를 바라보는지, 원하는 대상이 있는지 함께 확인해주세요.',
      );
  }
}
