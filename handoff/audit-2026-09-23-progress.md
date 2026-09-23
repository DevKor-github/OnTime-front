# OnTime 종합 개선 실행 인계 — 진행 중

기준 상태는 `plans/audit-2026-09-23/state.json`, 실제 전체 문답은 `issues/<ID>.md`다. 과거 상세 증거는 이슈별 validation JSON과 Git 기록에 있다.

## 사용자 요청과 경계

59개 개선과5개 기능 후보, 총64개를 상세 GitHub issue로 만들고 우선순위/의존성대로 구현·검증한다. 각 항목마다 새 전담 subagent가 grill-with-docs를 읽고 root에게 한 질문씩 보낸다. root가 사용자 대신 답하며 모든 실제 문답·정정을 이슈에 담고 게시 후 본문을 exact read-back한다. Android/iOS local-only: 서버/로그인/cloud sync/remote analytics 도입 없음.

이미 승인된 구현·검증·커밋·PR 갱신은 계속한다. 자동검증·실기기·병합·store 출시 상태를 구분하며 미실행 수용 조건이 있는 이슈는 OPEN으로 둔다. 활성 goal은 미완료다.

## 저장소와 게시 현황

- DevKor-github/OnTime-front, fix/audit-20260923-stabilization, Draft PR #585 (attach 완료).
- 감사 baseline44067d7a. main2b02fb77(PR590 recurring)을712b3708에서 통합했다. schema2/v1 migration, backupformat2/v1 호환, recurring ownership/frozen/exclusions, nearest60을 유지한다.
- 상세 이슈 **21/64개** 게시·exact read-back 완료, **43개 생성 전**.
- A01#583 A02#584 A03#586 A04#587 A05#588 A11#589 A12#591 A13#592 A14#593 A15#594 D03#595 U08#597 A06#598 A07#599 C01#600 A08#601 A09#602 D01#603 D02#604 D04#605 D05#606.
- A01–A05/A11/A12/A13 자동검증 통과, 기기/후속 통합 조건은 남음. U08 홈 overflow 선행 수정만 포함. A14 구현/CI 후 실제 registry ownership 보존 문제를 A15에서 후속 수정 중. A15는 아직 source freeze 전.
- D05까지 이슈별 설계가 확정됐으나 설계 게시와 구현 완료는 다르다.

## 최근 최종 검증

- A12 b9f959db: 원격707/analyze, coverage87.11%, Android APK/manifest 통과. a12-ci-validation.json.
- A13 sanitizer timing 보존 후 e2fbdf0b: 원격740/analyze,87.20%(11319/12981), Android 통과. artifact10763011276/APK0ba8caf4...; a13-persistence-ci-validation.json. 이전734는 sanitizer 결함 검출 증거가 아님.
- A14 282db21f source24 해시·focused100/full772/analyze/iOS26.5 SDK typecheck/AndroidSDK36 Kotlin compile 통과. artifacts/a14에는 실제 MyPage widget KO/EN PNG와 로그가 있음. OS 실기기 화면 아님.
- A14 b81259bf: Flutter35887794993 full772/analyze,87.44%(11487/13137), Android35887794956 통과. artifact10763053548/synthetic3ebcf192/APK7e88d688...; a14-ci-validation.json.
- A15 전 bebf2a31: Flutter35889125749 full772/analyze,87.33%(11472/13137), Android35889125735 통과. artifact10764089340/synthetic e53967c1/APKf8d95a14...; pre-a15-ci-validation.json. 동일 제품 소스여도 각 run의 coverage와 artifact identity를 섞지 않는다.
- A15 테스트: 결정적 snapshot barrier가 수정 전 실패. actual BackupService+Drift+owner restore/reset 경계33, UI/privacy/CRUD focused35 등 중간 결과 통과. 실제 CRUD/preparation/recurring nearest60 통합 후 최종 full/analyze 실행 중이며 최종 통과 숫자는 아직 없음.

## 현재 에이전트 및 다음 작업

1. `/root/grill_a15` 원래 전담이 source/test/A15.md/receipt를 소유해 구현 중. root는 tracking/GitHub/commit 소유. Flutter 명령을 병행하지 않는다.
2. A15는 단일 native owner·request cutoff/trailing drain·replacement generation을 구현한다. 취소 실패 최소 ownership을 실제 platform ID로 보존하고 repo upsert/dedup 왕복을 검사한다. reset marker 후 실패해도 DB/키를 지우거나 새 writer를 열지 않는다. DB start/finish 후 취소 오류를 durable commit 실패처럼 취급하지 않는다. actual BackupService/Reset/CRUD/Preparation/recurring 통합 증거 포함 필요.
3. A15 source freeze 이후 root hash/최종 tests/analyze/issue 전체 리뷰 반영을 확인하고 #594 read-back→명시적 staging→commit/push→새 SHA CI. A14 #593의 실제 ownership 후속 상태도 증거에 맞게 갱신한다.
4. 이후 D03 원래 전담 followup으로 durable crash journal/cleanup 구현. A15 인메모리 큐가 D03의 재시작 복구까지 완료했다고 주장하지 않는다. 전체 구현 순서는 README를 따른다.
5. D05 신규 전담 grill을 완료해 #606에 게시했다. 입력 암호문72MiB/평문64MiB/중첩32/일정100k/전체500k/정의별steps1000, 실제 bounded parsing·자료/그래프/시간대 검증·export 대칭·모바일 측정 계약이다. legacy duration에1440분을 일괄 강제하지 않고 과거 명시 offset 의미를 보존한다. D05 문답과 수용기준만 확정, 구현 전이다.
6. 다음 신규 전담은 A10. 이번 생성 시도는 agent thread limit으로 거절됐다. 다른 항목 전담을 재사용하지 말고 다음 실행에서 새 agent 생성. 사용자 승인 대기가 아니다. 그동안 A15 리뷰/검증을 계속한다.

## 확정 복구 계약

D01#603: DB 비의존 shell/typed bootstrap recovery, 기존 파일이 있으면 키를 새로 만들지 않음. D02#604: 실제 암호화 후보 DB/key pair·manifest atomic selection·recovery journal, 새 pair read-back 후 old cleanup. CONTEXT active key와 ADR0036은 e733c472로 기록. A09#602 정상 복원은 기존 설치 키+DB transaction/runtime generation 정리이며 D02 manifest를 불필요하게 쓰지 않음.

D04#605: 현재v1→v2가 이미 있다는 사실로 baseline 정정. DDL/version 원자성, 미래 schema 거부, 독립 역사 fixture, Android background SQLCipher loader/cipher_version guard 및 실제 모바일 검증을 요구한다. 현재 앱의 평문 유출을 재현했다는 뜻은 아니다.

## 환경과 주의

- Flutter `/Users/ejunpark/Library/flutter/bin/flutter`, Dart `/Users/ejunpark/Library/flutter/bin/cache/dart-sdk/bin/dart`, gh `/Users/ejunpark/.local/bin/gh`.
- shell은 login:false, sandbox_permissions를 넣지 않는다. Flutter 명령들은 ephemeral plugin 준비 경합을 피하도록 직렬 실행한다.
- generated Dart `*.g.dart`/config/mocks/freezed는 ignored local outputs이며 커밋하지 않는다. 기존 tracked l10n 출력은 변경 ARB와 함께 관리한다. root npm test는 의도적 실패 placeholder이므로 사용하지 않는다.
- 디스크 최근6.6GiB. 사용자 파일/다른 worktree를 정리하지 않는다. Android 연결기기 없고 물리iOS는 offline이었다.
- 부팅된 iPhone17/iOS26.5 simulator OnTime Recurring QA 20260923 (C8BA159D-A97A-458B-A5FC-B04A8B6F2848)의 upstream QA 앱·데이터는 보존한다. 발견만으로 실제 전달·provider·양방향복원 검증을 통과 처리하지 않는다.
- `/Users/ejunpark/.codex/worktrees/7b29/OnTime-front`는 다른 작업이다. 수정하지 않는다.
- helper `/tmp/ontime-ci-audit.py`는 전체40자리 head SHA를 요구하며 해당 head의 Flutter와 Android 결과/작은 artifact identity를 기록한다. short SHA의 빈 결과를 근거로 쓰지 않는다.
