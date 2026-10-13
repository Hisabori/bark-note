# Bark Note — Android / iOS

강아지의 소리 패턴을 기록하는 Flutter 네이티브 앱입니다.

## 기능
- 최대 60초 마이크 녹음, 앱을 백그라운드로 보내면 녹음 종료
- WAV 가져오기: 16-bit PCM, 8–96 kHz, 모노/스테레오, 5분 및 60 MB 이하
- 짖음 후보 횟수, 분당 횟수, 길이, 최대 20ms 프레임 RMS 음량(dBFS), 음량 그래프와 구간별 시작/종료 시간
- 상황 메모와 분석 기록을 앱 내부에 저장, 기록 조회 및 확인 후 삭제
- 분석은 기기에서 실행하며 서버나 계정이 필요하지 않음
- 직접 녹음한 임시 파일은 분석 성공/실패 후 삭제. 가져온 원본 파일은 변경하지 않음

## 감정 번역 (0.2)
- 상황 모름 / 초인종·낯선 사람 / 놀이·산책 / 혼자 있음 / 밥·관심 기다림 선택
- 경계·긴장, 기대·놀이 흥분, 불편함·접촉 요구 등의 가설과 표현 예시 제공
- 다른 가능성, 후보 평균 길이·간격, 선택한 상황과 관찰할 행동을 표시
- 후보 2개 미만이면 판단 보류. 상황 모름이면 여러 가능성을 유지
- 분석 저장 시 선택 상황과 해석을 함께 보관. 이전 기록도 열어 해석 가능
- 감정 학습 모델 없음. 임계값과 상황 연결은 개발자가 정한 미검증 규칙이며 연구에서 검증된 분류기가 아님. 검증된 확률/정확도 수치를 표시하지 않음
- 감정 처리 포함 직접 실행 검사 13개 통과. 실제 감정 정확도와 실기기 UI는 미검증

연구 참고: https://portal.fis.tum.de/en/publications/what-is-my-dog-trying-to-tell-me-the-automatic-recognition-of-the/ (이 앱의 규칙을 검증하는 자료는 아님)

## 분석 방식과 한계
20ms 프레임의 RMS 에너지를 계산하고, 낮은 20% 분위수보다 12dB 높은 기준(최소 -42dBFS)을 넘는 소리를 찾습니다. 120ms 미만 간격은 합치고 80ms–2초 구간을 후보로 집계합니다. 강아지 소리 분류 모델은 포함하지 않습니다. 후보에는 말소리·충격음이 섞일 수 있고 긴/작은 짖음을 놓칠 수 있습니다. 전체가 시끄러운 녹음에서는 감지가 누락될 수 있습니다. 감정 번역 카드는 소리 패턴과 사용자가 선택한 상황을 바탕으로 가능한 상태를 표현합니다. 실제 언어 번역이나 감정 확정, 의도·질병 진단이 아닙니다. 실제 환경에서의 정확도는 검증하지 않았습니다. dBFS는 보정된 실제 소음도(dB SPL)가 아닙니다.

## 실행 및 빌드
Flutter 3.47.7 / Dart 3.13.5로 소스 검사를 수행했습니다.

```sh
flutter pub get
flutter analyze
flutter test
dart tool/check_analysis.dart
flutter run
flutter build apk --debug
```
Android SDK와 Java 17이 필요합니다. 디버그 APK는 개발/테스트용이며 Store 제출용 서명은 포함하지 않습니다.

iOS는 Mac, Xcode, Flutter가 필요합니다.

```sh
flutter pub get
flutter build ios --debug --no-codesign
open ios/Runner.xcworkspace
```
Xcode에서 Signing & Capabilities의 Team과 고유 Bundle Identifier를 설정하고 연결한 iPhone을 선택해 실행하세요. 마이크 권한 설명은 프로젝트에 포함되어 있습니다. IPA 배포에는 Apple 서명과 provisioning이 필요합니다.

`.github/workflows/mobile.yml`은 Android APK와 서명 없는 iOS 빌드를 위한 수동/푸시 CI 예시입니다. 이 세션에서는 실행하지 않았습니다.

## 검증 결과
- Dart 정적 분석: 오류 없음
- 분석 엔진 직접 실행 6개 검사 통과: 반복 소리 횟수, 길이, 무음, 역위상 스테레오, 잘못된 헤더, 잘린 데이터
- Flutter 테스트 러너: Windows 도구 실행 오류로 완료하지 못함
- Android APK: Gradle의 Flutter 실행 단계에서 Windows NTSTATUS 0xC0000008로 실패, 설치 파일 미생성
- iOS 빌드/서명: Windows 환경에서 미수행
- 실기기 마이크, 파일 선택, 저장 및 UI 동작: 미검증

휴대폰에 설치한 뒤 마이크 권한 허용/거부, 60초 자동 종료, 백그라운드 전환, WAV 선택/취소, 분석 저장 후 앱 재시작, 기록 삭제를 확인해야 합니다.

