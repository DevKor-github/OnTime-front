# 반복 일정 iOS 실행 검증 — 2026-09-23

## 환경

- 전용 QA 시뮬레이터: `OnTime Recurring QA 20260923`, iPhone 17 / iOS 26.5.
- Simulator ID: `C8BA159D-A97A-458B-A5FC-B04A8B6F2848`.
- Flutter 3.44.4 / Dart 3.12.2 / Xcode 26.6, debug simulator build.
- 번들: `club.devkor.ontime.ios`, 소스 버전 `1.1.0+56` 유지.
- 기존 기기의 사용자 데이터를 쓰지 않고 새 QA 시뮬레이터에 설치했다.
- 앱 언어는 한국어, 약속 시간대는 Asia/Seoul이다. 호스트 네트워크 설정은 변경하지 않았다.

## 실행 결과

| 확인 | 관찰 결과 |
|---|---|
| Local-only 경계 | `dart run tool/check_local_only_boundary.dart` → `Local-only product boundary verified.` |
| iOS 빌드 | `flutter build ios --simulator --debug` 성공, `Runner.app` 설치·시작 성공 |
| 신규 설치 | 로그인 없이 초기 준비과정 설정, 알림 권한 허용, 홈 진입 |
| 반복 단위 | 반복 안 함·매일·매주·매월 표시, 매년 없음 |
| 실제 생성 폼 | 이름 → 날짜·반복 → 장소·이동 → 전용 준비 → 확인 → 저장 완료 |
| 검토 내용 | 월·목, 3회, 9/24·9/28·10/1 15:24, 준비 시작 14:50 표시 |
| 관리 화면 | 마이페이지 → 반복 일정 관리 → 상세에 같은 규칙, 종료 3회, 준비 3분 표시 |
| 프로세스 재시작 | `simctl launch --terminate-running-process` 이후 같은 일정과 전용 준비과정 유지 |
| 기본 준비 독립성 | 기본 준비를 3분에서 4분으로 저장하고 다시 읽음. 기존 반복 일정은 계속 3분 |
| 로컬 알림 등록부 | 재실행 후 세 회차가 각각 한 번씩 저장됨. provider는 `localNotification`, 준비 시작 14:50 KST와 일치 |

검증용 일정은 `반복 QA 출근`, 장소 `QA Office`, 준비 3분 + 이동 1분 + 여유 30분이다. UI 자동 입력 중 숫자가 덧붙은 것을 저장 전 검토에서 발견해 3회로 고쳤고, 최종 검토·저장·다시 읽기에서 3회를 확인했다.

알림 등록부는 앱이 보존한 예약 기록이다. 실제 OS 배너·소리 전달이나 실기기 AlarmKit 동작을 증명하지 않는다. 시뮬레이터에서는 로컬 알림 경로를 사용했다. 비행기 모드에서의 실기기 검증도 아직 수행하지 않았다.

## 증거

- [저장 전 3회 검토](review.png)
- [저장된 상세](saved-detail.png)
- [변경된 기본 준비 4분](default-updated.png)
- [재실행·기본 준비 변경 이후에도 전용 준비 3분](independent-after-relaunch.png)
- [세 회차 알림 등록부 요약](alarm-registry-summary.json)

## 추가 자동 검증

`test/domain/use-cases/recurring_alarm_integration_test.dart`의 3개 테스트가 통과했다. 실제 Drift DB, 반복·일정·준비 저장소, 알림 등록부의 JSON 저장/읽기, 재조정 use case를 연결하고 OS 예약 경계만 대체한다. SharedPreferences의 OS 저장소는 테스트 메모리 저장소를 쓴다.

1. 무기한 일 반복 두 묶음이 전역에서 가까운 60개 알림을 공유한다. 각 묶음의 전용 준비 25분을 사용하며 기본 준비 90분을 참조하지 않는다. 등록부와 재조정 객체를 새로 만들어도 중복 예약하지 않는다.
2. 한 회차 삭제 시 해당 예약만 취소하고 다음 후보로 용량을 채운다. 다시 구성해도 삭제한 회차를 예약하지 않는다.
3. 음수 UTC 오프셋 지역에서 현지 날짜가 전날이어도 실제 알림 시각이 미래이면 예약한다.

기존 전체 테스트 591개 통과에 더해 위 3개가 별도 통과했다. 추가 후 `flutter analyze`와 `git diff --check`도 통과했다. 이번 추가 검증에서는 제품 코드를 변경하지 않았다.

## 남은 기기·출시 확인

- 연결된 물리 iPhone/Android가 없어 실기기 전달 검증은 미실행이다. 사용자에게 기기 연결을 요청했다.
- 실기기에서 알림 허용/거부, 앱 종료·재부팅 후 전달, 알림 탭으로 해당 회차 진입, 장기 미실행 후 후보 보충을 확인해야 한다.
- Android 실행·빌드, iOS release archive/IPA, TestFlight/App Store 업로드 및 제출은 이번 추가 검증에서 수행하지 않았다.
- 디스크 여유 부족으로 첫 추가 테스트 컴파일이 중단됐다. 이번 작업의 `build/ios/Debug-iphonesimulator`와 `build/test_cache`만 정리한 뒤 테스트를 다시 실행해 통과했다. 설치 앱, 최종 simulator 앱 번들, 소스와 다른 작업 파일은 유지했다.
- QA 시뮬레이터와 검증용 데이터는 다시 열어 확인할 수 있도록 남겼다.
