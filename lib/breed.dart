/// User-selected labels, not classifications inferred from audio.
const dogBreeds = <String, String>{
  'unknown': '품종 모름',
  'mixed': '믹스견',
  'maltese': '말티즈',
  'poodle': '푸들',
  'pomeranian': '포메라니안',
  'bichon': '비숑 프리제',
  'shih_tzu': '시추',
  'chihuahua': '치와와',
  'yorkshire': '요크셔 테리어',
  'dachshund': '닥스훈트',
  'corgi': '웰시 코기',
  'shiba': '시바견',
  'jindo': '진돗개',
  'retriever_golden': '골든 리트리버',
  'retriever_labrador': '래브라도 리트리버',
  'border_collie': '보더 콜리',
  'beagle': '비글',
  'schnauzer': '슈나우저',
  'husky': '시베리안 허스키',
  'shepherd': '저먼 셰퍼드',
  'french_bulldog': '프렌치 불도그',
  'other': '기타 품종',
};
String normalizeBreed(Object? value) =>
    dogBreeds.containsKey(value) ? value as String : 'unknown';
String breedLabel(Object? value) => dogBreeds[normalizeBreed(value)]!;
bool canGroupBreed(String breed) =>
    dogBreeds.containsKey(breed) &&
    !{'unknown', 'mixed', 'other'}.contains(breed);
