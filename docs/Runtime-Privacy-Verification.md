# 파생 진행 기록 및 알림 payload 개인정보 검증

대상: A11 / [GitHub #589](https://github.com/DevKor-github/OnTime-front/issues/589). 신규 저장 형식과 기존 기록 전환을 함께 검사한다. 코드 검사·단위 테스트·플랫폼 타입 검사·실기기 전달을 구분한다.

## Native 실행 payload 경계

- Android/iOS route는 `type`, `scheduleId`, `alarmLaunchPayloadVersion`, `promptVariant` 네 필드만 허용한다. scheduleId는 문자열, UTF-16 기준 최대 512, 공백만 있는 값 및 ASCII 제어문자 거부다. 유효한 legacy hint는 version 9로 정규화하되 실제 일정 존재·완료 여부와 시작 확인은 Dart의 현재 DB 경로가 판단한다.
- 제목·본문·준비 원문·fingerprint·임의 명령·시간 덤프를 Flutter launch나 iOS URL/UserDefaults/AppIntent 신규 payload로 복사하지 않는다. Android provider 전달에는 취소 ID, 알람 시각, 표시 제목·본문이 별도로 필요하며 `deliveryExtras`로 한정한다. 최종 Flutter 실행 경계에서 이 필드들도 제거한다.
- Android MainActivity의 시작/새 intent/채널 조회, receiver, ringing activity와 자체 boot receiver 모두 임의 map 복사를 제거했다. `startPreparation` 명령 대신 현재 DB에 대한 확인 화면용 hint를 보낸다. registry의 cancellationPending 기록은 자체 boot receiver가 재등록하지 않는다. 전체화면 정책은 기존 비활성 상태다.
- iOS는 앱 시작 즉시 앱 소유 pending launch key를 정리하며, Dart 시작 정리에서도 `sanitizeStoredLaunchPayload`를 호출한다. 이전 dictionary는 허용 필드로 축소하고 잘못된 타입·ID는 해당 key만 삭제한다. 동기화 및 readback이 실패하면 채널 오류를 반환한다. URL의 중복 scheduleId는 임의의 마지막 값을 선택하지 않는다. AlarmKit 이전 AppIntent를 실행할 때도 다시 최소화한다.
- NativeLog의 map/intent 요약은 payload 값을 출력하지 않는다. iOS AppIntent의 scheduleId 로그도 제거했다. 과거 OS 로그·화면 캡처·저장 매체 잔재 삭제까지 증명하는 기능은 아니다.

## 실행한 네이티브 검사

| 검사 | 결과 | 증명 범위 |
|---|---|---|
| Kotlin/JVM `AlarmLaunchPayloadTest.kt` | 통과 | legacy 원문 제거, 임의 명령 차단, malformed identity 거부, idempotency, provider 표시와 route 분리, 취소 ID 보존 |
| Swift/macOS `AlarmLaunchPayloadTest.swift` | 통과 | 동일 allowlist, 실제 독립 UserDefaults suite의 legacy rewrite, malformed 삭제, 반복 실행, unrelated sentinel 보존, synchronize 실패·readback 불일치 거절 |
| Android 전체 Kotlin source + Android 36/Flutter jar 타입 컴파일 | 통과 | 앱/플랫폼 API 타입 연결. BuildConfig/R은 최소 generated-symbol stub이며 Gradle resource/linking 증거가 아님 |
| iOS AppDelegate + AlarmLaunchPayload + BackupExportPlugin 실제 simulator SDK typecheck | 통과 | UIKit/Flutter/AlarmKit 타입, Objective-C registrant header 연결. Runner linking/실기기 실행은 아님 |
| Xcode project plutil 및 Swift parse | 통과 | 파일 등록/문법 |

재현 명령:

```sh
kotlinc android/app/src/main/kotlin/club/devkor/ontime/AlarmLaunchPayload.kt \
  test/native/AlarmLaunchPayloadTest.kt -d /tmp/ontime-a11-launch-tests.jar
kotlin -classpath /tmp/ontime-a11-launch-tests.jar club.devkor.ontime.AlarmLaunchPayloadTestKt
xcrun swiftc ios/Runner/AlarmLaunchPayload.swift test/native/AlarmLaunchPayloadTest.swift \
  -o /tmp/ontime-a11-swift-launch-tests
/tmp/ontime-a11-swift-launch-tests
xcrun swiftc -typecheck -target arm64-apple-ios15.0-simulator \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk \
  -F /Users/ejunpark/Library/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_x86_64-simulator \
  -import-objc-header ios/Runner/Runner-Bridging-Header.h \
  ios/Runner/AppDelegate.swift ios/Runner/AlarmLaunchPayload.swift ios/Runner/BackupExportPlugin.swift
plutil -lint ios/Runner.xcodeproj/project.pbxproj
```

Android 전체 Kotlin 타입 검사는 동일 SDK/Flutter jar에 Google Maven의 `androidx.lifecycle:lifecycle-common:2.7.0`을 classpath로 사용했다. generated resource 이름 확인만 위한 임시 BuildConfig/R stub을 사용했으므로 CI의 실제 APK 빌드 결과를 별도로 확인한다.

## 실제 기기 및 업그레이드 검증 — 아직 미실행

1. 이전 버전으로 준비 이름 marker를 포함한 진행 기록·registry·fallback 예약·native pending launch를 만든다.
2. 새 버전으로 업데이트 후 첫 앱 시작에서 marker가 앱 소유 파생 저장소 및 public plugin pending payload에 남지 않는지 읽어 확인한다. raw DB/key는 변경하지 않으며 암호화 DB의 이름은 보존한다.
3. 첫 시작 이전의 재부팅, 첫 시작 중 DB 열기 실패, plugin 취소 실패, 저장소 쓰기 실패, 프로세스 종료를 각각 분리한다. 실패 시 성공 표시/완료 marker를 남기지 않고 후속 재시도를 확인한다.
4. 현재 일정 삭제·완료·준비 변경 뒤 이전 알림/URL/AppIntent를 열어 잘못된 일정 자동 시작이 없는지 확인한다.
5. Android fallback 및 iOS AlarmKit/fallback 각각 OS에 이미 표시된 알림과 예약을 검사한다. 실제 표시 내용은 상세 설정·언어·시간대별로 확인한다.

고정된 flutter_local_notifications 20.1.0의 boot receiver는 앱 첫 실행 전 자체 저장소를 읽어 재예약할 수 있다. 앱 첫 시작 이전에 플러그인 보관 원문이 제거됐다고 주장하지 않는다. 외부 플러그인 private JSON 직접 수정·fork는 이 범위에 포함하지 않는다. 알림 실제 전달·백업 교차 복원·merge/store release도 이 문서의 로컬 검사로 증명하지 않는다.

DB bootstrap이 runApp 이전에 실패하는 경로에도 raw transient 정리 호출을 추가했다. 이 시점의 복구 화면 표시는 기존 D01 항목의 미해결 범위이며, 정리 호출만으로 Recovery UI가 작동한다고 주장하지 않는다.

## Dart 검증 기록

A11 전담 grill agent의 최종 source freeze까지 전체 suite 634개가 통과했다. 이후 경계 보완은 targeted 59개, 마지막 DB 오류/orphan 구분·queued timer·schedule repository 변경은 관련 3개 test file의 42개가 통과했다. 최종 flutter analyze는 문제 없음이다. 전체634 결과를 마지막 추가 변경까지 동일 소스로 실행한 결과라고 부르지 않으며, commit 후 정확한 SHA의 원격 전체 CI로 확인한다.

이 검증은 versioned timing/shape identity, legacy exact serializer+별도 단계 검증, 원문을 제외한 진행 기록과 DB 재구성, 잘못된 events/ID/elapsed 거부, 앱 시작 전수 정리와 orphan 제거, 플랫폼 취소·readback 실패의 최소 ownership 재시도, confirmation marker 및 이미 큐에 들어간 timer event의 자동 시작 방지를 포함한다. DB unavailable은 앱 소유 runtime/early-start key만 제거하며 정상 source DB/key의 reset을 하지 않는다.

소스 SHA와 로컬 검증 경계는 `plans/audit-2026-09-23/a11-source-validation.json` 및 `a11-native-validation.json`에 기록한다. 로컬에서는 native 행동 테스트와 typecheck를 실행했으며 실제 기기 업그레이드 매트릭스는 위의 미실행 상태 그대로다.
