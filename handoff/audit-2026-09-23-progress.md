# 종합 개선 실행 상태 — 진행 중

이 파일은 완료 보고가 아니라 장기 실행의 인계 기록이다. 현재 상태의 기준은 `plans/audit-2026-09-23/state.json`, 이슈 상세/실제 문답은 `plans/audit-2026-09-23/issues/`다.

## 사용자 요청과 실행 규칙

- 감사 59개 개선 항목과 5개 기능 후보 전체(64개)를 상세 GitHub 이슈로 만들고 우선순위/의존성 순서로 구현·검증한다.
- 각 이슈마다 새로운 전담 서브에이전트가 grill-with-docs를 읽고 root에게 질문을 한 번에 하나씩 묻는다. root가 사용자 대리로 답하고 실제 질문/답변 전체를 이슈에 포함한다. 가상 인터뷰 금지.
- GitHub 게시 후 원격 본문을 read-back하여 로컬 원문과 대조한다.
- Android/iOS local-only 제품. 서버/로그인/자동 cloud sync/remote analytics를 추가하지 않는다.
- 실기기 검증을 자동 테스트나 빌드 성공으로 대체하지 않는다. 미실행 수용조건이 있으면 이슈를 열어 둔다.

## 저장소 및 전달

- 저장소: DevKor-github/OnTime-front
- 브랜치: fix/audit-20260923-stabilization
- Draft PR: https://github.com/DevKor-github/OnTime-front/pull/585 (현재 task에 attach 완료)
- 감사 baseline: 44067d7ab26b6290c16cdb13b99f57387dec08f6
- A01: #583, 6e17e764
- A02: #584, 35f4d603
- A03: #586, 8eab02bd
- A04: #587, c11d970c
- A05: #588, 0c41589e. 전체617 tests/analyze 및 Android release APK CI 통과. coverage84.98%. 실제기기·후속 통합 미완료
- A11: #589, 089afee5. 원격 전체 636 tests/coverage 84.96% 및 Android APK CI 통과. Native 행동/실제 SDK 타입검사 통과. 실제 기기 검증은 대기.
- A12: #591, 실제4Q&A 및12차 검토 원격readback완료. 소스 동결, 최신 집중107 tests/analyze/정책 통과. 최신 전체suite는 ENOSPC로 원격 CI 대기. 이전707개 결과와 구분.
- A13: #592, 실제3Q&A 포함본문readback완료. A12뒤구현대기.
- A14: #593, 실제 3문답과 플랫폼 관측·취소 기준을 게시하고 본문 read-back 완료. A13 뒤 구현 대기.
- A15: #594, 실제 4문답 전체 게시 및 read-back 완료, A14 뒤 구현 대기.
- D03: #595, 실제 4문답 및 Q4 보충 포함 본문 read-back 완료. 구현 대기. A12 소스는 grill_a12만 수정하며 root는 추적 문서와 GitHub를 담당.
- 나머지 이슈는 아직 생성 전이다. 전체 완료나 64개 생성 완료로 보고하지 않는다.

## 검증 경계

- A02 전체 Flutter 571개 및 analyze 통과.
- A03 실제 FileSelectorIOS host 계약 등10개 + restore 화면3개 통과.
- A04 통합 전체596개 통과 후 마지막2개 회귀는 targeted18개에 포함해 추가 통과. 수정 전 동일 회귀12개에서2pass/10fail. 실제 profile partial edit와 export snapshot 경합 테스트9개 통과. analyze 통과.
- A01/A02 head 35f4d603에 대한 GitHub Dart/coverage 통과, Android release APK 및 APK/merged manifest 통과: run35825051793. identity JSON은 plans/audit-2026-09-23/a01-apk-validation.json. 일회용 검증 서명이며 store release 아님.
- 최신 PR checks는 다시 읽어야 한다. 오래된 SHA 통과를 최신 결과로 보고하지 않는다.
- Android 연결기기 없음. iOS 물리 기기는 offline. 부팅된 iPhone 17/iOS 26.5 시뮬레이터 `OnTime Recurring QA 20260923` (C8BA159D-A97A-458B-A5FC-B04A8B6F2848)에 기존 반복 QA 앱/데이터가 있으므로 보존한다. 시뮬레이터 발견만으로 picker/provider/양방향 복원/실제 알림 전달 검증을 완료하지 않는다.
- Kotlin actual SDK compile, Swift plugin/XCTest typecheck 통과는 native runtime 테스트 및 전체 iOS linking과 다르다.

## 에이전트 실행 상태

신규 agent 생성 오류는 이전 에이전트 완료 후 해소됐다. 원래 요청한 항목별 새 전담 agent 방식을 유지한다. A12 구현 중, A13/A14는 각 원래 전담 agent가 이후 구현하며 D03 문답과 게시가 완료됐다. U08 신규 agent 생성은 일시 한도 오류로 대기하며 A12 완료 후 다시 시도한다. 이전의 새 작업 또는 agent 재사용 질문은 더 이상 진행 조건이 아니다.

## 로컬 환경

- Flutter: /Users/ejunpark/Library/flutter/bin/flutter
- Dart: /Users/ejunpark/Library/flutter/bin/cache/dart-sdk/bin/dart
- gh: /Users/ejunpark/.local/bin/gh
- shell 실행은 login:false. login shell에서 무관한 rbenv/디스크 오류가 있었음.
- 현재 worktree `.dart_tool`/codegen 준비됨. source 변경 후 generator 재실행, 생성 Dart는 ignored artifact로 commit 금지.
- 디스크 여유 최근 약0.3GiB로 줄었으며 수시로 변함. 무거운 iOS/Android local build 전에 확인하고 사용자 파일을 삭제해 공간을 만들지 않는다.
- baseline npm test는 의도적 실패 placeholder이므로 쓰지 않는다.

## 다음 작업

1. A12 전담 구현과 실제 router/Bloc/gate 회귀를 검토하고 source freeze 후 전체 테스트·커밋·CI를 진행한다.
2. U08 새 전담 grill을 생성해 홈 카드 overflow 근거를 이슈화한다. 오류를 숨기지 않고 430×932 홈 회귀를 좁게 선행 수정할 수 있도록 의존성을 정한다. A12 완료 뒤 A13, A14, A15 순서로 구현한다.
3. A12 커밋의 새 CI 결과와 APK identity를 기록하고 PR 및 이슈 검증 상태를 갱신한다. 통합 712b3708 CI는 모두 통과했다.
4. 기존 QA 데이터와 사용자 파일을 보존하며 native 검증 환경을 활용한다. 실행하지 못한 실제 기기 조건은 open 상태로 유지한다.

## Upstream main 통합과 CI

A11 커밋 `089afee51b2572339b4650bd3679b1a1ef72781e`의 원격 workflow_dispatch Flutter run 35828807338은 636 tests/coverage 84.96%, Android run 35828809625는 APK/manifest 통과다. 각 receipt를 plans에 기록했다.

작업 중 main에 PR #590 반복 일정 기능이 병합되어 PR #585가 충돌했다. PR baseRefOid/REST base.sha는 과거 기준을 반환했지만 git ls-remote 및 git/ref/heads/main은 `2b02fb770324de291488f3c74fe503dc063e2459`를 반환했다. 현재 main을 확인할 때 PR base 필드에 의존하지 않는다.

Root는 main을 통합하면서 backup_service_test.dart 충돌 하나를 양측 회귀 보존으로 해결했다. 반복 일정, DB schema2 및 v1 migration, backup format2/v1 호환과 기존 감사 수정을 함께 검증했다. 생성기, local analyze, 전체 678 tests, generated/local-only 정책 검사가 통과했다. 통합 커밋 `712b37081f95ea30aa6d1c61072d167ddaec78de`를 push했고 PR은 MERGEABLE이다. 원격 Flutter run 35829634205도 678 tests와 coverage 85.35% (10679/12512)를 통과했다. Android run 35829634224도 통과했고, PR synthetic merge 31158b42의 APK identity를 upstream-integration-apk-validation.json에 기록했다.

A12는 통합 이후 구현을 재개했다. A13/A14/A15 문답 준비는 독립적으로 진행하되 소스 구현은 순차적이다. 후속 감사(D04 migration, F01 반복 일정 등)는 upstream 기능으로 해결된 범위를 재평가해야 한다. 감사 baseline은 44067d7a이며, 현재 통합한 main은 2b02fb77이다.

## 추가 UI 회귀 발견

A12 실제 router 테스트에서 EN, 430×932/DPR1/text scale1, 실제 Pretendard 폰트로 home_screen_tmp.dart:185가 14px overflow했다. 원본 로그는 /tmp/a12-overflow.log, 영속 사본은 plans/audit-2026-09-23/u08-home-overflow-baseline.txt다. 390×844의 A12 경로는 통과한다. 홈 소스는 아직 수정하지 않았고 U08 전체 완료를 의미하지 않는다. 신규 grill_u08 생성이 2회 한도 오류로 실패했으며 A12 완료 뒤 다시 시도한다. 사용자에게 새 질문을 할 상황이 아니며 이미 준비된 A13 구현 등 진행 가능한 작업을 계속한다.

A12 최종 소스24개 SHA-256을 a12-validation.json과 대조해 일치 확인했다. 선택한 준비 C→D→홈 실제 router 경로를 검증했다. 신규 U08 agent 생성 및 기존 A13 followup 모두 agent thread limit 오류였으며 조건 완화 없이 재시도/기존 확정 이슈 구현을 진행한다.

## 2026-09-24 이어서 실행

A12 b9f959db commit/push 및 PR 원격 head 확인 완료. GitHub Flutter run35881988783, Android run35881988613 실행 중. PR 상세 본문 갱신·동일성 read-back 완료. Agent 한도 해소 후 신규 U08/A06 전담 grill과 기존 A13 전담 구현이 실행 중이며 root가 실제 질문에 순차 답변한다. A12 이전707개 결과는 최종 소스 검증으로 재사용하지 않는다.

A12 최종 b9f959db Flutter run35881988783이 707 tests/analyze/coverage87.11% (11189/12844) 통과했다. 이전 로컬707과 수는 같지만 최종 source에 대한 별도의 원격 증거다. Android run35881988613은 계속 실행 중.

U08 #597와 A06 #598 생성 후 exact body read-back 완료. 13/64개 이슈 게시, 51개 생성 전. U08 홈 선행패치 구현 중(전체 매트릭스 완료 아님). A06 문답3개 및 OFF정책 정정 포함 준비 완료, A07 새 전담 grill 시작.

A12 Android run35881988613 통과, artifact10760609601 및 synthetic merge1c8e60c3 identity read-back 완료. 상태 code_verified_device_pending. #591 본문에 최종 Flutter707/87.11%·APK 기록 추가 후 exact read-back 완료.

A07 #599 상세본문/실제3문답과추가정정 게시후 exactreadback완료. 전체14/64개게시, 50개미생성. A14는최신A13소스readonly구현준비중이며A13commit전소스수정금지.

U08 홈선행패치 sourcefreeze, 18 tests/analyze 및 root PNG시각검토/모든hash 일치. #597 본문업데이트 exactreadback완료. 전체U08미완료 유지. C01 신규전담grill시작.

A13 `59d92bdd03cdd5e2dc33e95dd844f8d0bb508eab` 구현커밋. 최종전체734/analyze/정책통과; #592본체증거링크를정확commit영구링크로갱신후exactreadback완료. U08선행홈commit bde8b2de도포함. A14전담구현허용, C01/A08새전담grill진행. 원격push/CI확인이어가기.

C01 #600 exactreadback완료: 15/64게시,49미생성. A08/A09전담grill진행중. A13/U08 push원격head dac9c5a2, Flutter35884708345/Android35884708227 실행중. A14조사에서 _safe가notificationTiming필드를drop하는A13실제persistence gap발견, 별도A13fix와realSharedPreferences왕복회귀우선처리. 기존734통과가이gap을커버하지못했음을명시.

A13 persistence후속 `edfff97c4806fb2d154c324edf8965b1feb218e0`: sanitizer필드보존+actualdatasource/SharedPreferences mock 왕복10개통과, 원격#592본문갱신exactreadback완료. A08 #601 게시exactreadback완료, 전체16/64게시. A09문서작성중,D01새전담grill시작.
