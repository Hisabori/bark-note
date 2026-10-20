# 나갈때 — 수도권 지하철 통합 앱 초안

Android/iOS Flutter 앱입니다. 실시간 열차는 휴대폰에서 서울시 API를 직접 호출하며 별도 서버가 필요 없습니다. 인터넷 연결은 필요합니다. 기존 Node.js 서버는 선택 기능용 참고 소스입니다.

## 구현 범위
- 출발 플랜: 출발역, 목적지, 목표 도착 시각(KST), 도보·열차/환승·대기·도착 도보·여유 시간 입력
- 입력한 전체 이동시간을 빼서 출발 시각 계산
- 덜 붐비는 시간: 연결한 실제 30분 통계에서 승강장 도착/대기 이후 탑승 시간대를 비교하고, 목표 시각 내 도착할 수 있는 2시간 이내 출발 후보를 최대 3개 추천
- 실시간 도착정보: 서울시 TOPIS 어댑터, 방향 필터, 정보 갱신 시각, 2분 이상 된 정보의 ETA 보류, 0초 값을 확정 도착시각으로 바꾸지 않음
- 실시간 출발 계산: 열차 카드에서 노선·방향·종착역을 선택하면 도보 + 탑승 여유 1분으로 탈 수 있는 다음 열차를 골라 출발 마감·예상 도착·목표 도착 여유를 표시합니다. 이동·환승은 입력값 기준이고 종착역 이후 경로는 검증하지 않습니다.
- 이동 계획과 목표 도착 시각 복원. 목표 시각이 지난 계획은 다시 확인해야 합니다.
- Android/iOS 네이티브 로컬 알림 예약·취소 소스 포함
- Android 부팅 후 미래 알림 복원, Android 13 이상 알림 권한 처리
- 이동시간과 서버 설정을 기기에 저장. API 키는 앱에 넣지 않음

## 현재 상태 / 미구현
- 기본 인증키는 GitHub Actions Secret에서 빌드 시 주입합니다. 공개 소스에는 포함하지 않으며 앱 설정에서 교체할 수 있습니다. 설치 파일에서는 추출될 수 있습니다. 실제 API 응답과 기기 동작은 아직 검증하지 못했습니다. 혼잡도 통계는 연결되지 않았습니다. 제품 화면에 예시 열차나 혼잡도를 실제 데이터로 표시하지 않습니다.
- 자동 경로 탐색, 버스 경로, 운행 지연을 반영한 출발시간 재계산, 실시간 칸별 혼잡도는 아직 구현하지 않았습니다.
- 출발 시각은 사용자가 입력한 소요시간 기준입니다. 시간표·열차 운행 여부·막차·실제 환승 가능성을 보장하지 않습니다.
- 통계 혼잡도는 오늘 서울 날짜에 대해서만 비교합니다. 공휴일 여부는 사용자가 요일 통계를 직접 선택해야 합니다.
- 서울교통공사 공개 통계는 특정 구간·방향의 30분 평균입니다. 전체 경로의 혼잡도나 좌석 확보 확률이 아닙니다.
- 실시간 도착정보 지원 노선·역 범위는 제공기관의 제공 범위와 다를 수 있습니다.
- 로컬 알림은 고정된 시각에 예약됩니다. 앱을 닫은 상태에서 실시간 운행을 감시하지 않습니다. OS 절전/권한/강제종료 등에 따라 알림이 지연되거나 누락될 수 있습니다.

## 앱 실행
Flutter 3.47.7 기준입니다.

```sh
flutter pub get
flutter analyze
flutter test
dart tool/check.dart
flutter run
flutter build apk --debug
```

iOS는 Mac과 Xcode가 필요합니다. `flutter build ios --release --no-codesign` 후 Xcode 또는 별도 서명 도구로 서명해 설치하세요. iOS Swift 네이티브 브리지는 이번 환경에서 컴파일하지 못했습니다.

## 서버 실행
Node.js 20 이상, 외부 npm 의존성 없음.

```sh
cd server
node --test
# SEOUL_API_KEY 환경변수에 발급받은 서울시 지하철 API 인증키 설정
# CROWD_JSON_PATH 환경변수에 아래 형식의 통계 JSON 파일 경로 설정
npm start
```

기본 주소는 `127.0.0.1:8787`입니다. 실제 휴대폰 앱 연결에는 HTTPS 리버스 프록시/서버를 구성하고 앱 설정에 주소를 넣으세요. 앱은 HTTPS만 사용합니다. `HOST`와 `PORT`로 서버 바인딩을 변경할 수 있습니다. 인증키를 저장소나 앱 소스에 올리지 마세요.

도착정보는 역별 30초 캐시를 적용합니다. 제공기관의 할당량 안에서 사용해야 합니다. 현재 구현의 upstream URL이 제공기관 환경에서 HTTPS 요청을 지원하는지 실제 인증키로 확인해야 합니다. 미지원 시 제공기관이 승인하는 전송 방식의 전용 서버 구성이 필요합니다.

### 혼잡도 통계 파일
제품에는 가짜 혼잡도 값이 들어 있지 않습니다. 공식 자료에서 정확한 원본 수치를 옮겨 아래 구조로 준비하세요. 빈 파일 예시는 `server/data/crowd.template.json`에 있습니다.

- source: 원본 데이터 페이지 HTTPS URL
- asOf: 원본 통계 기준일 (YYYY-MM-DD)
- rows: station(역명), line(노선 원본 값), direction(원본 방향 값), day(weekday/saturday/sunday), minute(자정 이후 분, 0~1439, 30분 단위), percent(원본 혼잡도 %)
- 원본 통계와 동일하게 노선/방향을 구분해야 합니다. 앱 설정의 노선·방향 값과 정확히 일치해야 합니다.

앱 서버 API:
- GET /v1/arrivals?station=역명
- GET /v1/crowd?station=역명&line=노선&direction=방향&day=weekday

## 데이터 출처와 연결 조건
- 실시간 도착정보: https://data.seoul.go.kr/dataList/OA-12764/A/1/datasetView.do
- 30분 평균 혼잡도: https://data.seoul.go.kr/dataList/OA-12928/A/1/datasetView.do
- 실시간 칸별 혼잡도 향후 연동 참고: https://openapi.sk.com/products/detail?linkMenuSeq=312
- 자동 길찾기 향후 연동 참고: https://lab.odsay.com/guide/guide?platform=web

공개 혼잡도 자료는 출처표시·변경금지 조건이 명시되어 있으므로 원본 수치를 보존하고 기준일/출처를 표시하도록 설계했습니다. 이 프로젝트에 원본 데이터 파일은 재배포하지 않습니다.

## 검증
- Dart 정적 분석 통과
- 출발·혼잡도 추천 핵심 계산 8개 직접 실행 검사 통과
- 서버 파싱/오래된 정보 처리/통계 범위/누락 설정 처리 4개 단위 검사 통과
- HTTP 통합 검사는 샌드박스의 로컬 연결 제한(EACCES)으로 미수행. 허용된 환경에서 `RUN_HTTP_TESTS=1 node --test` 실행
- Android APK 빌드는 Gradle 내부 통신 제한(Could not connect to Gradle daemon)으로 실패
- APK/IPA 파일 미생성. 실기기 UI·알림·실시간 외부 API는 미검증

## 로컬 기본 인증 설정
현재 로컬 서버의 .env에 공공데이터포털 키가 DATA_GO_KR_SERVICE_KEY로 설정되어 있습니다. 서울시 전용 SEOUL_API_KEY와 별개입니다. 활용 신청한 서비스명/엔드포인트가 아직 지정되지 않아 공공데이터포털 실시간 조회는 미연결입니다. npm start가 자동으로 읽습니다. 기존 환경변수가 있으면 기존 값을 우선 사용합니다. 로컬 .env는 Git과 배포 ZIP에서 제외합니다. 제공기관 인증 성공 여부는 아직 확인하지 않았습니다. 배포 서버에는 별도로 인증키를 환경변수로 설정해야 합니다.



## 직접 호출 빌드
GitHub Actions: .github/workflows/local-mobile.yml, rail-time-local 브랜치.
RAIL_SEOUL_API_KEY Secret을 Dart define으로 주입합니다. 일반 사용자는 서버 주소를 입력할 필요가 없습니다.
서울시 공식 API는 HTTP 방식이므로 swopenapi.seoul.go.kr 도메인에만 Android/iOS 통신 예외를 허용했습니다. 키와 조회 역 이름이 암호화되지 않은 통신으로 전송됩니다.
IPA는 미서명 기기용으로 Sideloadly의 로컬 재서명이 필요합니다. Android release APK는 개발용 서명입니다.

