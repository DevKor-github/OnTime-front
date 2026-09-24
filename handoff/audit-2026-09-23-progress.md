# OnTime 종합 개선 실행 인계 — 진행 중

기준 상태는 `plans/audit-2026-09-23/state.json`, 실제 전체 문답은 `issues/<ID>.md`다. 과거 상세 증거는 이슈별 validation JSON과 Git 기록에 있다.

## 사용자 요청과 경계

59개 개선과5개 기능 후보, 총64개를 상세 GitHub issue로 만들고 우선순위/의존성대로 구현·검증한다. 각 항목마다 새 전담 subagent가 grill-with-docs를 읽고 root에게 한 질문씩 보낸다. root가 사용자 대신 답하며 모든 실제 문답·정정을 이슈에 담고 게시 후 본문을 exact read-back한다. Android/iOS local-only: 서버/로그인/cloud sync/remote analytics 도입 없음.

이미 승인된 구현·검증·커밋·PR 갱신은 계속한다. 자동검증·실기기·병합·store 출시 상태를 구분하며 미실행 수용 조건이 있는 이슈는 OPEN으로 둔다. 활성 goal은 미완료다.

## 저장소와 게시 현황

- DevKor-github/OnTime-front, fix/audit-20260923-stabilization, Draft PR #585 (attach 완료).
- 감사 baseline44067d7a. main2b02fb77(PR590 recurring)을712b3708에서 통합했다. schema2/v1 migration, backupformat2/v1 호환, recurring ownership/frozen/exclusions, nearest60을 유지한다.
- 상세 이슈 **28/64개** 게시·exact read-back 완료, **36개 생성 전**. 최신 현황은 아래 2026-09-24 갱신 절 참조.
- A01#583 A02#584 A03#586 A04#587 A05#588 A11#589 A12#591 A13#592 A14#593 A15#594 D03#595 U08#597 A06#598 A07#599 C01#600 A08#601 A09#602 D01#603 D02#604 D04#605 D05#606.
- A01–A05/A11/A12/A13 자동검증 통과, 기기/후속 통합 조건은 남음. U08 홈 overflow 선행 수정만 포함. A14 구현/CI 후 실제 registry ownership 보존 문제를 A15에서 후속 수정 중. A15는37파일 해시·795 tests/analyze 검증 뒤 ecd04293363fa79bd9cd1b140169619dfc083b96로 커밋했다.
- D05까지 이슈별 설계가 확정됐으나 설계 게시와 구현 완료는 다르다.

## 최근 최종 검증

- A12 b9f959db: 원격707/analyze, coverage87.11%, Android APK/manifest 통과. a12-ci-validation.json.
- A13 sanitizer timing 보존 후 e2fbdf0b: 원격740/analyze,87.20%(11319/12981), Android 통과. artifact10763011276/APK0ba8caf4...; a13-persistence-ci-validation.json. 이전734는 sanitizer 결함 검출 증거가 아님.
- A14 282db21f source24 해시·focused100/full772/analyze/iOS26.5 SDK typecheck/AndroidSDK36 Kotlin compile 통과. artifacts/a14에는 실제 MyPage widget KO/EN PNG와 로그가 있음. OS 실기기 화면 아님.
- A14 b81259bf: Flutter35887794993 full772/analyze,87.44%(11487/13137), Android35887794956 통과. artifact10763053548/synthetic3ebcf192/APK7e88d688...; a14-ci-validation.json.
- A15 전 bebf2a31: Flutter35889125749 full772/analyze,87.33%(11472/13137), Android35889125735 통과. artifact10764089340/synthetic e53967c1/APKf8d95a14...; pre-a15-ci-validation.json. 동일 제품 소스여도 각 run의 coverage와 artifact identity를 섞지 않는다.
- A15 테스트: 결정적 snapshot barrier가 수정 전 실패. actual BackupService+Drift+owner restore/reset 경계33, UI/privacy/CRUD focused35 등 중간 결과 통과. 실제 CRUD/preparation/recurring nearest60 통합 후 최종 frozen source full795/analyze 통과, aggregate de887b4e5d34a0ac9c37d62e92a652128fabde3ae1ddcb6dc54d6eccff446dd2. a15-validation.json에37파일/로그해시·초기실패·수정 근거를 기록했다.

## 현재 에이전트 및 다음 작업

1. A15 원래 전담은 최종37파일 동결을 완료했고 root가 source/log hash를 대조해 ecd04293로 commit/push했다. #594/#593의 로컬 검증 본문을 exact read-back했다. 새 원격 CI를 해당 전체SHA로 추적한다.
2. A15에는 단일 native owner·request cutoff/trailing drain·replacement generation, 실제 platform ID ownership 보존, reset 실패 gate와 actual BackupService/Reset/CRUD/Preparation/recurring 회귀가 포함된다. 실제 mutation 테스트의 추가 reconcile 호출을 제거해 접수 누락을 숨기지 않는다.
3. `/root/grill_d03` 원래 전담에 ecd04293363fa79bd9cd1b140169619dfc083b96를 전달하고 D03 소스/테스트/D03문서/receipt 구현 권한을 줬다. root는 tracking/GitHub/commit 소유. Flutter 명령을 병행하지 않는다.
4. D03은 A15 owner/cleanup을 재사용해 independent durable journal, bootstrap interrupted-reset, typed partial/retry UI, 최소 D01 시작 복구를 구현한다. 영속 journal 검증 후 A15의 임시 '취소 실패면 DB 보존/같은프로세스 재시도 금지'를 확정 D03의 'quiesce된 취소반환 후 원문삭제+cleanup pending/retry' 계약으로 확장할 수 있다. 실제 사용자데이터/기존simulator는 보존한다.
5. D05 신규 전담 grill을 완료해 #606에 게시했다. 입력 암호문72MiB/평문64MiB/중첩32/일정100k/전체500k/정의별steps1000, 실제 bounded parsing·자료/그래프/시간대 검증·export 대칭·모바일 측정 계약이다. legacy duration에1440분을 일괄 강제하지 않고 과거 명시 offset 의미를 보존한다. D05 문답과 수용기준만 확정, 구현 전이다.
6. A10 사전 read-only 확인: ScheduleBloc:244/835, Home timer:39, TodaysScheduleTile:158, adjacent usecase:54/73에 scheduleTime 직접 비교가 남아 있다. occurrenceInstantUtc의 offset-null fallback은 device-local toUtc이고 CivilTimeResolver unknown zone은 UTC fallback이다. 이 사실만으로 모든 civil-date 조회를 instant 비교로 일괄 치환하지 말고 A10 전담이 calendar bucket/commitment 의미를 구분해야 한다. 다음 신규 전담은 A10. 이번 생성 시도는 agent thread limit으로 거절됐다. 다른 항목 전담을 재사용하지 말고 다음 실행에서 새 agent 생성. 사용자 승인 대기가 아니다. 그동안 A15 리뷰/검증을 계속한다.

## 확정 복구 계약

D01#603: DB 비의존 shell/typed bootstrap recovery, 기존 파일이 있으면 키를 새로 만들지 않음. D02#604: 실제 암호화 후보 DB/key pair·manifest atomic selection·recovery journal, 새 pair read-back 후 old cleanup. CONTEXT active key와 ADR0036은 e733c472로 기록. A09#602 정상 복원은 기존 설치 키+DB transaction/runtime generation 정리이며 D02 manifest를 불필요하게 쓰지 않음.

D04#605: 현재v1→v2가 이미 있다는 사실로 baseline 정정. DDL/version 원자성, 미래 schema 거부, 독립 역사 fixture, Android background SQLCipher loader/cipher_version guard 및 실제 모바일 검증을 요구한다. 현재 앱의 평문 유출을 재현했다는 뜻은 아니다.

## 환경과 주의

- Flutter `/Users/ejunpark/Library/flutter/bin/flutter`, Dart `/Users/ejunpark/Library/flutter/bin/cache/dart-sdk/bin/dart`, gh `/Users/ejunpark/.local/bin/gh`.
- shell은 login:false. 네트워크/Git index·ref/Flutter SDK cache에 필요한 경우 승인된 require_escalated를 사용한다. Flutter 명령들은 ephemeral plugin 준비 경합을 피하도록 직렬 실행한다.
- generated Dart `*.g.dart`/config/mocks/freezed는 ignored local outputs이며 커밋하지 않는다. 기존 tracked l10n 출력은 변경 ARB와 함께 관리한다. root npm test는 의도적 실패 placeholder이므로 사용하지 않는다.
- 디스크 최근6.6GiB. 사용자 파일/다른 worktree를 정리하지 않는다. Android 연결기기 없고 물리iOS는 offline이었다.
- 부팅된 iPhone17/iOS26.5 simulator OnTime Recurring QA 20260923 (C8BA159D-A97A-458B-A5FC-B04A8B6F2848)의 upstream QA 앱·데이터는 보존한다. 발견만으로 실제 전달·provider·양방향복원 검증을 통과 처리하지 않는다.
- `/Users/ejunpark/.codex/worktrees/7b29/OnTime-front`는 다른 작업이다. 수정하지 않는다.
- helper `/tmp/ontime-ci-audit.py`는 전체40자리 head SHA를 요구하며 해당 head의 Flutter와 Android 결과/작은 artifact identity를 기록한다. short SHA의 빈 결과를 근거로 쓰지 않는다.

## 최신 push 및 진행 중 CI

최신 pushed HEAD는818e99c99f9a3892fb2588bd471d2ea21a00f42c(A15 전달 추적)다. PR585 본문 exact read-back 및 Draft를 확인했다. Flutter run35891562919는 in_progress, Android35891562976은 pending, Widgetbook35891562910은 조건상 skipped다. 다음 실행은 같은 전체SHA의 최종 결과를 기록한다. source 구현 SHA는ecd04293363fa79bd9cd1b140169619dfc083b96다. D03 전담에 구현 권한이 전달됐으므로 source37 freeze 검증을 이후 D03 WIP와 혼동하지 않는다.

## A15 최종 CI / D03 root 인계 / A10 사용량 제한

818e99c99f9a3892fb2588bd471d2ea21a00f42c의 Flutter35891562919 전체795/analyze·coverage87.66%(11668/13310), Android35891562976 APK/manifest 모두 성공. artifact10765597396/synthetic1d3f41c0/APK02285d398344cff0b2ae7ebeadc30456c7622715df488fa862eacc2db29ed1ff. a15-ci-validation.json과 #594/#593/PR585 exact read-back 완료.

A10 전담 `/root/grill_a10` 신규 생성은 성공했지만 실제 질문 전에 usage limit 오류로 종료됐다. A10 이슈/문답을 만들었다고 주장하지 않는다. 같은 agent 재개 가능 시 신규 다른 전담을 쓰지 않고 이어간다. D03도 usage limit으로 종료돼 root가 이미 확정된4문답에 따라 이어받았다. 이는 사용자가 승인하지 않은 작업이거나 목표 전체 blocker라는 뜻이 아니다.

D03 WIP: 신규 alarm_journal_store{,_native,_web}, alarm_ownership_journal, local_reset_protocol 및 기존 owner/cleanup/CancelAll 변경. root는 staged-first-write를 빈 설치로 취급하지 않게 하고, journal 중복 실제ID/불가능한 완료상태 거부, intent write 응답 불명확 시 데이터삭제 금지·gate보호, pending ownership의 기존 timing enum 보존을 추가했다. 실제 임시파일 23개 focused 테스트와 analyze 통과. d03-journal-progress.json에 해당 파일/로그 해시와 한계를 기록했다. 현재 제품 서비스/bootstrap/UI에는 아직 프로토콜 연결 전이며 전체 regression/실제kill/device는 미실행이다. D03 WIP를 A15의795 전체검증 결과와 섞지 않는다.

D03 다음: actual LocalResetActions(검증 가능한 marker/key/prefs/file/launch삭제), LocalDataResetService+bootstrap 공통 프로토콜, D01 최소 pre-DI 복구 shell/KO·EN partial·retry UI 연결. runtime shared owner가 이제 actual FileStore이므로 기존 test fixture가 path_provider 없는 shared singleton에 의존하던 부분을 명시적 격리 주입으로 정비하되 product에서 MemoryStore로 조용히 우회하지 않는다. actual file tests는 반드시 유지. registry decode 실패를 빈 성공으로 바꾸지 말고 orphan/unknown provider 관측과 독립 journal로 안전하게 연결. staged-only first-write가 영구막힘으로 끝나지 않도록 명시적 보존/복구 경로가 필요하다. 무응답 Future는 owner를 유지하고 UI만 제한 대기로 표시해야 한다.

공식 Dart3.12.2 runtime/bin/file_macos.cc는 rename(), file_linux.cc는 renameat() 호출을 확인했다. 같은 디렉터리 temp→rename로 이전 committed 파일을 유지하는 설계이며 directory fsync/갑작스런 전원손실 보장은 주장하지 않는다. Dart 공개 File.rename 문서만으로 원자성을 입증한 것이 아니다. Android backup_rules/data_extraction_rules의 root/file 제외는 존재하고 iOS 기존 excludeFromBackup bridge를 호출하지만 실제 mobile read-back/backup 검증은 남아 있다.

현재 sandbox는 workspace-write/auto-review로 바뀌었다. Flutter SDK 캐시, GitHub 네트워크, git index/ref 변경은 필요한 require_escalated 실행으로 자동검토를 받았다. 거절은 없었고 승인된 읽기/테스트는 완료했다. 기본 권한 Flutter 실행은 SDK telemetry/cache 경로로 실패했으며 제품 테스트 실패가 아니다.


## 2026-09-24 D03 제품 연결 및 독립 리뷰 보완 중

현재 pushed HEAD는 `0efdd3adb28293d3ff9f6b80bcd9091229384bd5`(A15 최종 CI 기록)이며 아래 D03 제품 변경은 아직 미커밋이다. 앞선 “제품 서비스 연결 전” 문단은 초기 milestone 기록이다.

Root가 LocalDataResetService/LocalDataLifecycle bootstrap에 공통 reset protocol을 연결하고 DB/키/prefs/legacy credentials/native launch 각 단계의 read-back을 추가했다. pre-DI LocalStartupGate와 ResetAwareApp이 초기화 중 기존 앱을 폐기하고 KO/EN typed partial/retry/complete를 표시한다. 실제 알림 소유 기록은 preferences 삭제와 독립인 file journal에 먼저 기록한다. 실제 OS 호출이 반환되기 전에는 owner를 해제하지 않고 UI 10초 안내만 바꾼다. 손상된 legacy registry는 원문을 scrub하되 불명확한 취소 소유권 표시를 journal로 옮겨 보존한다. iOS 명시 fullreset의 app-scoped AlarmKit 전체 취소+조회는 별도 native call로 제한하고 ordinary OFF에서는 호출하지 않는다. Android는 잃어버린 legacy native ID의 부재를 확인할 수 없으므로 unknown을 거짓 완료로 바꾸지 않는다.

중간 검증: shared production FileStore에 기대던 단위 테스트를 명시적 isolated owner로 정비한 뒤 full829 passed. 뒤이어 추가 reset boundary45 passed. 실제 별도 Flutter 프로세스 SIGKILL 6지점/새 프로세스 복구 통과(완성된 write checkpoint, fake provider/deletion adapters, 실제 모바일·부분write·전원손실 증거 아님). 실제 복구 위젯 KO/EN partial/complete 4 PNG를 430×932 logical /2x raster/200% text/번들 fonts로 생성해 root가 모두 열어 확인했다. Swift 실제 iOS26.5 SDK typecheck 및 Kotlin Android36+Flutter embedding compile 통과. `d03-journal-progress.json`과 `artifacts/d03/`에 중간 로그/이미지/해시 보관. 이 중간 결과를 이후 변경된 최종 소스의 전체 통과로 쓰지 않는다.

원래 D03 에이전트가 사용량 제한 후 재개되어 독립 리뷰했다. P1: legacy reset marker만 있고 journal/registry가 비면 과거 취소 실패를 잃은 상태를 empty success로 처리한다는 결함. root가 marker-only unknown 보존 및 회귀 추가. 추가로 완료 service receipt를 캐시해 아주 늦은 progress mount/재호출에서 삭제를 새로 실행하지 않도록 수정했다. P2: malformed JSON/partial first pending의 영구 startup 차단. 원래 전담 `/root/grill_d03`가 실제 parse corruption과 I/O/unsupported/semantic-invalid를 구분하고 quarantine→최소 ownership 재구성→검증, reset 의도 없으면 데이터 삭제 금지 경로를 구현 중이다. 현재 Flutter 명령 소유자는 D03 전담이고 root는 제품 파일/Flutter 실행을 멈췄다. agent의 source freeze 보고 후 root가 최종 sourcehash/analyze/full/host-kill/UI·정책검사를 묶어 검증해야 한다.

A10 원래 전담도 재개되어 실제 Q1~Q4/root 답변 완료. civil/instant 구분, device today vs original-zone calendar, unresolved zone/gap/overlap, timezone-neutral civil carrier, bundled tzdb 변경의 명시 확인과 restore staging 계약 확정. root가 ADR0021 보충 및 CONTEXT의 기존 rule-update 한 문장을 반영했다. A10 상세 문서는 agent가 작성 중이며 아직 GitHub 이슈 생성 전이다. U02 신규 전담 spawn은 agent thread limit으로 실패했으므로 생성/문답을 꾸미지 않는다. 다음 기회에 새 U02 전담을 생성한다. 이미 grill 완료한 A06 등은 D03 후 우선순위대로 구현 가능하다.

## 2026-09-24 D03 최종 로컬 검증

D03 원래 전담의 P2 구현과 root 연결이 완료됐다. 전체872/집중71,87.99%,analyze/generated/local-only 및 native SDK compile 통과.579파일 재해시에서제품/test소스 변경없음, QA 대역에 명시적unknown설정만추가 후 hostSIGKILL11 모두통과. d03-final-validation.json 및artifacts/d03/final 참조. 원격CI와실기기검증별도. U02#609 게시/readback23/64,41개생성전. C08 전담grill진행, glossary root반영. 다음구현A06#598.

## 최신 main 통합 및 다음 작업

main c7184b2a Figma PR607 충돌을659a5fc4에서해결,복구operation인자오류074d5fd6수정. 관련36tests+실제UIcapture2통과,root3화면직접확인. 원격074d5fd6 CI확인중. D03상세이슈최신본문은아직게시대기. C08#610/U01#611 게시검증하여25/64,39개생성전. U01CONTEXT/ADR0034 독점/공유원문삭제정책root반영. A06전담구현agent가Flutter소유권가지고focused/analyze/full준비중,root제품파일수정금지. U03전담grill문답중.

## D03 원격 검증 완료 및 A06 전달

D03최종main통합074d5fd6 원격Flutter882/analyze/88.50%,AndroidAPK/manifest통과 artifact10786008849(identity d03-ci-validation.json). A06d06474d4 실제periodic수정commit,47boundary/929full/88.74%,7blob검증완료(a06-final-validation.json),#598본문원격대조완료. U03#612 실제3문답+28case게시26/64,38개생성전. T03전담grill실제3문답확정문서작성중. A07전담구현시작,Flutter명령소유권A07. root는A06docs/push/CI후상위우선구현계속.

## 2026-09-24 최신 상태 — A06 CI 완료 / A07 구현 중

- 원격 HEAD `e6c1438ebcd641386081bb5aa5569e1b7da7ee15`; Draft PR #585 OPEN/MERGEABLE read-back. main `c7184b2ae477e6a24a47fd0b9da79d3ed52b8cf4`의 Figma #607을 통합했다.
- 추가 상세 이슈: A10#608, U02#609, C08#610, U01#611, U03#612, T03#613, T04#614. 실제 전담 grill 문답 전체 및 원격 본문 동일성 확인. 총28/64;36개 생성 전.
- D03 `5f3adf11` 구현, main 통합 후 `074d5fd6` 원격882 tests/analyze·88.50% 및 Android release APK/manifest 성공. 독립 journal, JSON/UTF8 손상 격리, unknown ownership, reset 단계 read-back, host SIGKILL11지점 검증. 기기 조건 미완료. d03-final/main-integration/ci-validation.json 참조.
- A06 `d06474d4` 구현: 실제 periodic→Refresh→NotificationService→channel,47경계/929전체, local88.74%. HEAD e6c1438e 원격 run35945420027은929 tests/analyze·88.79%(13099/14753); Android35945419975 success, artifact10786697671, synthetic0896d865, APKd0f64d4e914bbeb6dcaf7f37e9c62fdaa8f9b35b9b5fc0df673f8fc561c51007. a06-ci-validation.json 참조. #598 OPEN, 기기 pending.
- `/root/implement_a07`가 제품/테스트와 Flutter 실행을 독점하며 진행한다. 실제 DB 원자성/실패 재시도/중복 revision/완료 시작 거부 회귀, commit 전 화면 유지·commit 후 pending 배너, run 시각/유효 snapshot 복구를 구현 중이다. 미커밋 A07을 A06 검증 결과로 간주하지 않는다.
- A07 root의 중간 'DB T0를 모든 새 run에 강제' 제안은 기존 Q2 보충/Q3에 맞지 않아 철회했다. DB 최초 T0는 invariant; 유효한 같은 run T1은 유지; 재확인 후 명시 새 run T2는 독립. owner 교체 자체는 새 run 의도가 아니다. 실제 리뷰/철회도 최종 A07 이슈에 보존할 것.
- A07 root 리뷰 추가: 같은 run의 upcoming stream refresh가 새 ScheduleState.started를 만들 때 pending 배너 상태를 잃지 않아야 한다. 에이전트가 회귀 확인 중.
- `/root/grill_t01` 신규 전담은 고정 e6c1438e 코드로 T01의 실제 문답을 시작했다. docs/T01만 소유하며 Flutter 실행 금지. T04는 문서 완료/게시, T03/T04와 CONTEXT 보완은 다음 docs 커밋 대상.
- 다음 구현 C01→A08→A09→D01→D02→D04→D05→A10→U02→C08→U01→U03→T03→T04→T01→T02… 우선순위/의존성 계획 유지. 전부 완료되지 않았으며 active goal 계속.

## 2026-09-24 A07 완료·C01 착수 최신 갱신

A07 source d73c7863a01343004ccadcd72064b563c464dd0d: 동결29파일과commitblob root재해시일치, 실제DB수정전3결함재현, focused56/full944,coverage88.67%(13289/14987),analyzer/generated/local-only/Python11/manifest통과. KOEN200%합성receipt캡처4장 및 실제스크롤/skip/다음단계 접근검증. DB버튼통합은실제Drift+latch로별도증명. source기기/CI아직별도. a07-final-validation.json 및artifacts/a07보존; #599본문실제추가리뷰/철회+결과exactreadback.

T01#615,T02#616 게시하여30/64(34생성전). T02 P03의 schedule-start OS예약과A06 activeperiodic 전달범위를명확히분리하는후속문구검토중. C01#600 /root/implement_c01이workflow/typed결과/UI분리및previewclaim실제Drift회귀구현중이며Flutter독점. C01claim이후OS취소대기중일반writer변경은최종DBtransaction revision검사로overwrite방지하되기수행OS부작용을receipt에보존한다. 완전한writer fencing/staging/runtime전이는A09통합미완료로명시한다. /tmp/c01-review-transcript.md에실제문답기록.

PR본문갱신은자동승인검토의거절로사용자승인대기중이며우회하지않는다. 로컬준비본문 /tmp/ontime-audit-pr.md. 해당한정승인대기와무관한승인된구현/상세이슈작업계속.
