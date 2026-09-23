# 모바일 백업 내보내기 검증

대상: 감사 A02 / [GitHub #584](https://github.com/DevKor-github/OnTime-front/issues/584). 아래 기록은 2026-09-23의 로컬 소스 검사다. 실제 문서 picker·저장 provider·양방향 복원은 아직 **미실행**이며 이 이슈는 검증 완료가 아니다.

## Native 구현 계약

- Method channel `ontime/backup_export`, method `export`, `encryptedBytes`(Uint8List), `suggestedName`(String).
- 결과 `saved` / `cancelled`; 에러 `export_busy` / `export_failed`. 경로·URI·비밀번호·데이터를 오류나 로그에 포함하지 않는다.
- Android는 앱 `noBackupFilesDir/backup_exports`에 암호문을 쓰고 fsync/readback byte 비교 후 ACTION_CREATE_DOCUMENT를 연다. ContentResolver 쓰기·flush·close가 모두 성공해야 saved다. URI를 File 경로로 변환하지 않는다.
- iOS는 전용 caches 하위 폴더를 OS 백업에서 제외하고 파일 보호를 적용해 암호문을 저장·동기화·readback 비교한 뒤 export-as-copy picker에 제공한다. delegate 완료만 saved다.
- 양쪽 disk IO는 직렬 background queue에서 실행한다. attempt의 own temporary directory는 결과 전달 전에 정리하며 정리 실패는 다음 startup에서 재시도한다. 외부 저장 성공을 임시파일 정리 실패로 뒤집지 않는다.
- Android는 URI만으로 새 문서의 소유권을 증명할 수 없으므로 실패한 외부 문서를 임의 삭제하지 않는다. 일반 오류 메시지에 불완전 파일 잔존 가능성을 포함한다.
- Android activity detach는 진행 중 작업을 중단 처리하며, 요청 ID는 프로세스 내 재사용하지 않는다. 16비트 범위가 소진되면 새 요청은 재시작 안내와 실패로 끝난다. 재생성 전 picker의 늦은 callback이 새 export를 완료할 수 없다.
- write/flush/close 완료 후 saved receipt가 확정된 뒤 detach는 이미 확인한 saved를 유지한다. 그 이전 detach는 보수적으로 실패시킨다. Dart lifecycle generation 검사가 새 DB에 과거 freshness를 기록하지 못하게 한다.
- iOS presentation 거절·scene disconnect·cancel callback은 성공으로 바꾸지 않는다. 정상 background만으로는 picker 작업을 취소하지 않는다.

## 실행한 검사

| 검사 | 결과 | 증명 범위 |
|---|---|---|
| Dart 서비스·port·gate 회귀 테스트 16개 | 통과 | snapshot revision, 취소/실패, single-flight, late callback, DB mark 실패 |
| 비밀번호·export 화면 widget 테스트 5개 | 통과 | 제출/취소 전환 중 controller 수명, 결과별 안내와 busy 해제 |
| 전체 Flutter 테스트 | 571개 통과 | 기존 회귀 포함. 실기기/네이티브 UI 실행 아님. |
| flutter analyze | 문제 없음 | Dart 정적 검사 |
| Kotlin native plugin의 실제 Android 36/Flutter jar 컴파일 | 통과 | 타입 및 실제 플랫폼/Flutter API 연결. APK 빌드·실행은 아님. |
| Swift native plugin iOS 15 simulator target typecheck | 통과 | UIKit/Flutter API와 타입. Runner 전체 빌드·delegate 런타임 실행은 아님. |
| Swift native plugin isolated Runner module 생성 및 RunnerTests typecheck | 통과 | malformed payload/경로 입력에 실패를 반환하는 XCTest 소스 컴파일. XCTest 실행 결과는 아님. |
| AppDelegate Swift parse | 통과 | 등록 코드 구문만 검사. 앱 전체 linking은 검사하지 않음. |
| Xcode project `plutil -lint` | 통과 | 프로젝트 문법. 실제 Sources compile/link는 별도 필요. |
| `git diff --check` | 통과 | 패치 공백 오류. 동작 증거는 아님. |

Dart 결과의 대상 파일은 `test/core/backup/backup_file_export_port_test.dart`, `test/core/backup/backup_service_test.dart`, `test/core/database/local_data_operation_gate_test.dart`, `test/presentation/my_page/my_data_export_test.dart`다. 첫 widget 실행에서 dialog exit transition 도중 controller가 너무 일찍 dispose되는 실제 오류를 발견했고, root가 dialog State 소유로 고친 뒤 5개 테스트가 통과했다. 같은 변경에서 전체 Flutter suite 571개와 analyzer도 통과했다.

실행한 명령(환경 절대경로를 보존해 재현 가능하게 기록):

```sh
kotlinc android/app/src/main/kotlin/club/devkor/ontime/BackupExportPlugin.kt \
  -classpath /Users/ejunpark/Library/Android/sdk/platforms/android-36/android.jar:/Users/ejunpark/Library/flutter/bin/cache/artifacts/engine/android-arm64/flutter.jar \
  -d /tmp/ontime-a02-native-classes

xcrun swiftc -typecheck -target arm64-apple-ios15.0-simulator \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk \
  -F /Users/ejunpark/Library/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_x86_64-simulator \
  ios/Runner/BackupExportPlugin.swift

mkdir -p /tmp/ontime-a02-swift
xcrun swiftc -emit-module -enable-testing -module-name Runner \
  -emit-module-path /tmp/ontime-a02-swift/Runner.swiftmodule \
  -target arm64-apple-ios15.0-simulator \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk \
  -F /Users/ejunpark/Library/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_x86_64-simulator \
  ios/Runner/BackupExportPlugin.swift
xcrun swiftc -typecheck -I /tmp/ontime-a02-swift \
  -I /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/usr/lib \
  -target arm64-apple-ios15.0-simulator \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk \
  -F /Users/ejunpark/Library/flutter/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64_x86_64-simulator \
  -F /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks \
  ios/RunnerTests/RunnerTests.swift
xcrun swiftc -frontend -parse ios/Runner/AppDelegate.swift
plutil -lint ios/Runner.xcodeproj/project.pbxproj
git diff --check
```

## 남은 실행 매트릭스

모든 행은 현재 **미실행**이다. 합성 QA 데이터만 사용하고 비밀번호는 기록·첨부하지 않는다. 실제 기록에는 commit SHA, 앱 version/build 및 바이너리 digest, 기기/OS, provider, fixture의 SHA-256, 기대/실제 결과, 화면/로그 위치를 넣는다.

| 시나리오 | Android | iOS | 기대 결과 |
|---|---|---|---|
| 전체 앱 빌드 및 native tests | 미실행 | 미실행 | 등록·linking 성공, native 실패 contract tests 실행 |
| 로컬 문서 picker 저장→같은 파일 다시 열기 | 미실행 | 미실행 | 전체 파일 인증/복호화 및 cutoff 일치 |
| picker 취소 | 미실행 | 미실행 | 성공 안내 없음, freshness 불변, own tmp 정리 |
| 임시 저장 실패/디스크 부족 | 미실행 | 미실행 | 외부 문서를 성공 처리하지 않음 |
| provider 쓰기/flush/close 오류 | 미실행 | 미실행 | 불완전 파일 가능성 안내, freshness 불변 |
| 같은 suggestedName으로 반복 저장 | 미실행 | 미실행 | provider 이름 정책 기록, 기존 파일의 잘못된 삭제 없음 |
| background/복귀 | 미실행 | 미실행 | 중복 callback·중복 성공 없음 |
| activity 재생성/scene disconnect | 미실행 | 미실행 | 미확정 결과 성공 추정 없음, 재시도 가능 |
| 프로세스 종료 후 재시작 | 미실행 | 미실행 | orphan 정리, 자동 이어쓰기 없음 |
| 중복 export와 다른 비밀번호 | 미실행 | 미실행 | busy, 데이터·결과 혼합 없음 |
| export 중 일반 편집 | 미실행 | 미실행 | snapshot 이후 변경은 미백업 유지 |
| export 중 restore/reset | 미실행 | 미실행 | 서비스 gate로 경합 거절, 새 DB에 늦은 mark 없음 |
| 외부 저장 후 DB mark 실패 | 미실행 | 미실행 | 파일은 유지, 상태 기록 실패만 안내 |
| 명시적 외부 document provider | 미실행 | 미실행 | OnTime 네트워크 추가 없음, cloud sync 완료 주장 없음 |
| Android 저장→iOS 복원 | 미실행 | 미실행 | 전체 durable 필드 동등, runtime 제외 |
| iOS 저장→Android 복원 | 미실행 | 미실행 | 전체 durable 필드 동등, runtime 제외 |

A03(iOS import 형식), D07(템플릿 createdAt), A09(복원 runtime 정리)가 교차 복원 비교를 막으면 해당 의존성을 해결하고 다시 검증한다. compile/typecheck 통과만으로 위 미실행 상태를 바꾸지 않는다.
