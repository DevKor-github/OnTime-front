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
- A11: #589, source freeze. 전체634 및 이후targeted59/최종42, analyze 통과. Native 행동/실제SDK 타입검사 통과. Root commit/CI 및 실제기기 검증 추적
- A12: #591, 실제4Q&A·15AC 원격readback완료. grill_a12 구현중.
- A13: #592, 실제3Q&A 포함본문readback완료. A12뒤구현대기.
- A14: 신규grill_a14가문답중,소스수정없음.
- 나머지 이슈는 아직 생성 전이다. 전체 완료나 64개 생성 완료로 보고하지 않는다.

## 검증 경계

- A02 전체 Flutter 571개 및 analyze 통과.
- A03 실제 FileSelectorIOS host 계약 등10개 + restore 화면3개 통과.
- A04 통합 전체596개 통과 후 마지막2개 회귀는 targeted18개에 포함해 추가 통과. 수정 전 동일 회귀12개에서2pass/10fail. 실제 profile partial edit와 export snapshot 경합 테스트9개 통과. analyze 통과.
- A01/A02 head 35f4d603에 대한 GitHub Dart/coverage 통과, Android release APK 및 APK/merged manifest 통과: run35825051793. identity JSON은 plans/audit-2026-09-23/a01-apk-validation.json. 일회용 검증 서명이며 store release 아님.
- 최신 PR checks는 다시 읽어야 한다. 오래된 SHA 통과를 최신 결과로 보고하지 않는다.
- Android 연결기기 없음, iOS 연결기기 offline. picker/provider/양방향복원/실제알림 전달 미검증.
- Kotlin actual SDK compile, Swift plugin/XCTest typecheck 통과는 native runtime 테스트 및 전체 iOS linking과 다르다.

## 에이전트 실행 상태

이전 turn에서 신규 생성이 `agent thread limit reached`로 실패했지만 사용자 "계속해" 메시지 이후 재시도하여 `/root/grill_a12` 신규 생성이 성공했다. 새 작업/기존 agent 재사용 선택은 더 이상 진행 조건이 아니다. 원래 요청한 이슈마다 새 전담 agent 방식을 유지한다. A12는 read-only 조사와 grill을 시작했으며 GitHub issue는 아직 생성 전이다. A11은 최종 문답 기록 후 root가 commit/CI를 진행한다.

## 로컬 환경

- Flutter: /Users/ejunpark/Library/flutter/bin/flutter
- Dart: /Users/ejunpark/Library/flutter/bin/cache/dart-sdk/bin/dart
- gh: /Users/ejunpark/.local/bin/gh
- shell 실행은 login:false. login shell에서 무관한 rbenv/디스크 오류가 있었음.
- 현재 worktree `.dart_tool`/codegen 준비됨. source 변경 후 generator 재실행, 생성 Dart는 ignored artifact로 commit 금지.
- 디스크 여유 최근 약400MiB로 줄었으며 수시로 변함. 무거운 iOS/Android local build 전에 확인하고 사용자 파일을 삭제해 공간을 만들지 않는다.
- baseline npm test는 의도적 실패 placeholder이므로 쓰지 않는다.

## 다음 작업

1. A05 전체617 tests/analyze 통과한 변경의 CI 및 실제 기기·후속 통합 증거 추적.
2. A11 상세 범위대로 fingerprint/runtime/native payload 개인정보 전환을 구현·검증.
3. 신규 grill_a12와 문답을 마쳐 전체 실제 문답을 포함한 A12 issue를 만든 뒤 우선순위 순서로 구현.
4. native device 및 iOS build 검증은 실제 환경을 확보해 별도 수행. 이슈 open 상태와 코드/CI/merge/release를 구분.

## Upstream main 통합과 CI

A11 head089afee51b2572339b4650bd3679b1a1ef72781e push뒤 PR585가dirty여서 동일head에workflow_dispatch Flutter35828807338/Android35828809625를실행했다(둘다통과: Flutter636,coverage84.96%,AndroidAPKreceipt기록). 원인은 GitHub오류가아니라작업중main에PR590이병합된것이었다. PR baseRefOid/REST base.sha는기존44067d7a로보였지만 git ls-remote 및 git/ref/heads/main은 최신2b02fb770324de291488f3c74fe503dc063e2459를반환했다. 실제현재main ref를읽어야한다.

Root는 문답기록37fc0144 commit후 git fetch origin main 및 merge --no-ff --no-commit origin/main을실행했다. test/core/backup/backup_service_test.dart의충돌1개를양측테스트보존으로해결했고, 자동병합4코어파일을확인했다. 생성기완료, 전체678 tests/analyze 및 policy/diff검사통과. 로그는 /tmp/ontime-upstream-merge-analyze.log 및 /tmp/ontime-upstream-merge-tests.log. Root가mergecommit/push후A12구현재개한다. generated파일추적금지.

A12는소스편집전잠시대기시켰다. 통합검증/mergecommit후 /root/grill_a12에followup_task로구현재개지시한다. A13/A14는계획/문답만하며소스편집금지. 이후각항목구현전에새main기능으로이미해결된부분을다시판정한다(예:D04 v1→v2migration, 반복기능후보). 원래감사baseline은44067d7a로유지하되currentbase는2b02fb77이다.
