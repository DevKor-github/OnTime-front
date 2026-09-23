# OnTime 종합 개선 실행 인계 — 진행 중

현재 상태의 기준은 `plans/audit-2026-09-23/state.json`, 실제 문답과 이슈 본문은 `plans/audit-2026-09-23/issues/`다. 과거 검증 상세는 이슈별 validation JSON과 Git 기록을 읽는다.

## 사용자 요청과 제품 경계

감사 59개 개선 항목과 기능 후보 5개, 총64개를 상세 GitHub 이슈로 만들고 우선순위/의존성 순서로 구현·검증한다. 항목마다 새 전담 서브에이전트가 grill-with-docs를 읽고 root에게 한 질문씩 보낸다. root가 사용자 대신 답하며 실제 전체 문답을 이슈에 넣고 게시 후 원격 본문과 대조한다. Android/iOS local-only 제품이며 서버·로그인·자동 cloud sync·remote analytics를 추가하지 않는다.

실행하지 않은 수용 기준이 있으면 이슈는 열어 둔다. 테스트·빌드·PR·병합·실기기 전달·store 출시는 각각 다른 상태다. 사용자 추가 승인 없이 이미 확정한 범위의 구현, 커밋, Draft PR 갱신을 이어간다.

## 현재 저장소와 이슈

- 저장소 DevKor-github/OnTime-front, 브랜치 fix/audit-20260923-stabilization, Draft PR #585 (task attach 완료).
- 감사 baseline44067d7a. upstream PR590 반복 일정 main2b02fb77을 712b3708에서 통합했다. schema2/v1 migration, backupformat2/v1 호환, 반복 소유권·frozen·exclusions 및 가까운 미래60개 계약을 보존한다.
- 상세 이슈 **19/64개** 게시 및 exact read-back 완료, **45개 생성 전**.
- A01#583, A02#584, A03#586, A04#587, A05#588, A11#589, A12#591, A13#592, A14#593, A15#594, D03#595, U08#597, A06#598, A07#599, C01#600, A08#601, A09#602, D01#603, D02#604.
- A01–A05/A11/A12/A13은 구현·자동 검증을 마쳤으나 기기 또는 후속 통합 조건이 남아 있다. U08은 홈 overflow 선행 패치만 구현했으며 전체 큰 글자 매트릭스는 미완료다.
- A14는 source24개 동결 및 root hash 대조를 완료했고 receipt·전용 UI 캡처·커밋 전달을 마무리 중이다. A15 원래 전담은 readonly 준비를 마쳤으며 A14 commit 이후 구현한다.
- A06/A07/C01/A08/A09/D01/D02/D03/A15의 실제 문답 및 상세 계획은 게시됐지만 구현 완료는 아니다.

## 최근 검증과 코드 기준

- A12 b9f959db: remote707 tests/analyze, coverage87.11%, Android APK/manifest 통과. a12-ci-validation.json. 실제 OS cold-tap 미실행.
- U08 bde8b2de: 실제 폰트430×932 홈14px overflow 수정. focused18, analyzer 및 전용 PNG 검토. 전체 매트릭스 미완료.
- A13 59d92bdd: 정확 시각 권한·실제 timing receipt·선택적 안내 구현, 로컬734 tests. 이후 registry sanitizer가 timing을 누락하는 실제 결함을 발견해 edfff97c로 별도 수정, actual datasource/SharedPreferences mock 왕복6개 추가.
- A13 최종 후속 head e2fbdf0b: Flutter run35885445743 전체740/analyze·coverage87.20%(11319/12981), Android run35885445710 APK/manifest 통과. artifact10763011276, synthetic merge67efb127, APK SHA2560ba8caf4d01d1c043b7c237af1c67a42626bff73743d58d5a011e93c747a293a. a13-persistence-ci-validation.json에 기록. 이전734 결과는 sanitizer 결함의 검출 증거가 아니다.
- A14 최종 frozen source는 focused100, 전체772 tests/analyze, 실제 iOS26.5 SDK typecheck 및 AndroidSDK36/Flutter Kotlin compile을 통과했다. 중간 Flutter 명령 동시 실행의 ephemeral symlink 실패는 테스트 시작 전 환경 오류였고 같은 소스로 직렬 재시도해 통과했다. APK/Runner 전체 linking·실기기 전달과 구별한다.
- D02 결정으로 CONTEXT active key 용어를 정정하고 ADR0036을 e733c472에 기록했다. 정확히 한 active pair와 후보/retired의 한시 보존, manifest/store epoch와 DB runtime generation의 역할을 분리한다. 설계 확정이며 구현 완료가 아니다.

## 에이전트와 다음 작업

1. A14 전담 `/root/grill_a14`의 최종 receipt/capture를 읽고 root가 #593 본문 exact read-back→명시적 source staging→commit/push→새 SHA CI를 기록한다. A14 동결 소스를 임의 수정하지 않는다.
2. `/root/grill_a15` 원래 전담에 A14 commit SHA를 전달하고 확정 #594 범위를 구현하도록 한다. 작은 단일 알림 writer, request cutoff별 완료와 trailing rerun, replacement quiesce/late native 반환 소유권을 지킨다. D03의 durable crash journal이나 D02 manifest를 여기서 완료했다고 주장하지 않는다.
3. 이후 D03→A06→A07→C01→A08→A09 순서와 README 전체 우선순위를 따른다. 독립적인 다음 grill은 병행 가능하다.
4. D04 신규 전담 생성은 agent thread limit으로 두 번 거절됐다. 다른 이슈 전담을 재사용하지 말고 슬롯/다음 실행에서 다시 생성한다. 기존 A15 전담 followup은 정상 접수됐다. 사용자 추가 승인/새 작업 요청은 필요 없다.
5. D04 사전 read-only 확인: upstream schema2와 실제 v1→v2 onUpgrade가 존재한다. recurring_migration_test는 현재v2 파일에서 반복 표면을 제거해 v1처럼 만든 파일을 재연다. 따라서 감사 baseline의 'migration 없음'을 그대로 재게시하지 말고 고정 과거 schema fixture·upgrade 실패 rollback/키 보존 등 실제 남은 범위를 새 전담 grill로 재평가한다.

## 환경과 주의

- Flutter `/Users/ejunpark/Library/flutter/bin/flutter`, Dart `/Users/ejunpark/Library/flutter/bin/cache/dart-sdk/bin/dart`, gh `/Users/ejunpark/.local/bin/gh`.
- shell은 login:false, sandbox_permissions를 넣지 않는다. Flutter 명령들은 ephemeral plugin 준비 경합을 피하도록 직렬 실행한다.
- generated Dart `*.g.dart`/config/mocks/freezed는 ignored local outputs이며 커밋하지 않는다. 기존 tracked l10n 출력은 변경 ARB와 함께 관리한다. root npm test는 의도적 실패 placeholder이므로 사용하지 않는다.
- 디스크 최근6.6GiB. 사용자 파일/다른 worktree를 정리하지 않는다. Android 연결기기 없고 물리iOS는 offline이었다.
- 부팅된 iPhone17/iOS26.5 simulator OnTime Recurring QA 20260923 (C8BA159D-A97A-458B-A5FC-B04A8B6F2848)의 upstream QA 앱·데이터는 보존한다. 발견만으로 실제 전달·provider·양방향복원 검증을 통과 처리하지 않는다.
- `/Users/ejunpark/.codex/worktrees/7b29/OnTime-front`는 다른 작업이다. 수정하지 않는다.
- helper `/tmp/ontime-ci-audit.py`는 전체40자리 head SHA를 요구하며 해당 head의 Flutter와 Android 결과/작은 artifact identity를 기록한다. short SHA의 빈 결과를 근거로 쓰지 않는다.

## A14 전달 완료와 A15 시작

A14는 282db21f5effa86eb2f82c81c247d57a0a6acfd0로 커밋했다. source24 해시 및 최종100/772/analyze/native SDK receipt와 전용 KO/EN PNG를 포함한다. #593 본문에 최종 구현/증거 링크를 넣고 exact read-back했다. A15 원래 전담에게 해당 SHA를 전달하고 구현을 허용했다. A14 원격 CI는 push 이후 새 head로 확인하며 아직 통과를 주장하지 않는다.
