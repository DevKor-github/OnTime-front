# OnTime 종합 개선 실행 계획

사용자 요청: 감사 59개 개선 항목과 5개 기능 후보 전체. 각 항목 전담 서브에이전트가 grill-with-docs로 질문하고 root가 답한다. 합의 및 실제 전체 문답을 상세 GitHub 이슈에 포함한 뒤 구현한다.

- 제품 방향: Android/iOS local-only; 서버, 로그인, 자동 원격 분석 도입 없음.
- 이슈는 grill 종료 후 게시하고 원격 본문을 다시 읽어 로컬 원문과 대조한다. 초안/진행/코드검증/기기검증/병합/출시는 구분한다.
- 구현은 아래 우선순위와 의존성 순서. 다음 이슈의 독립적인 grill은 준비 작업으로 병행할 수 있다.
- 자동검증 통과만으로 기기 수용조건을 삭제하지 않는다. 외부 검증 대기인 이슈는 열어 두고 진행 가능한 다음 항목을 계속한다.
- 실제 질문과 답만 기록한다. 코드로 답 가능한 문제는 탐색하고, 신규 제품 용어만 CONTEXT에 즉시 반영한다. 일반 구현 선택에는 ADR를 남발하지 않는다.
- 코드 생성 산출물은 commit하지 않는다. 테스트·빌드·store 상태는 현재 변경 SHA와 artifact를 기준으로 확인한다.
- 이 계획은 사용자 승인된 실행을 추적한다. 요청 범위에 필요한 issue/PR 게시와 코드 수정은 진행하며, 관련 없는 데이터 삭제나 사용자 파일 정리는 하지 않는다.

기준 감사: [전체 보고서](../../docs/App-Improvement-Audit-2026-09-23.md). 기계 판독 상태: [state.json](state.json). 이슈별 본문·문답: `issues/<ID>.md`.

## 현재 GitHub 연결

| 항목 | 이슈 | 구현 상태 |
|---|---|---|
| A01 | [#583](https://github.com/DevKor-github/OnTime-front/issues/583) | receiver·APK manifest CI 통과, 실기기 전달 대기 |
| A02 | [#584](https://github.com/DevKor-github/OnTime-front/issues/584) | native export·gate·Dart/Android build 검증, 실기기 파일 I/O 대기 |
| A03 | [#586](https://github.com/DevKor-github/OnTime-front/issues/586) | 실제 iOS plugin 계약·복원 취소 화면 검증, iOS 전체 build·기기 대기 |
| A04 | [#587](https://github.com/DevKor-github/OnTime-front/issues/587) | partial update·transaction 회귀 및 통합 CI 통과, merge 대기 |
| A05 | [#588](https://github.com/DevKor-github/OnTime-front/issues/588) | 전체617 tests/analyze·Android APK CI 통과, coverage84.98%, 기기·후속 통합 대기 |
| A11 | [#589](https://github.com/DevKor-github/OnTime-front/issues/589) | 089afee5 원격636 tests/84.96%·APK 통과, 최신main 통합678 tests 통과, 기기 검증 대기 |
| A12 | [#591](https://github.com/DevKor-github/OnTime-front/issues/591) | 콜드 탭·선택 준비 유지 구현, 최종 b9f959db 원격707 tests/analyze·coverage87.11%·APK 통과, 기기 검증 대기 |
| A13 | [#592](https://github.com/DevKor-github/OnTime-front/issues/592) | 예약/안내·registry 후속 수정 원격740 tests/87.20%·APK 통과, 기기 대기 |
| A14 | [#593](https://github.com/DevKor-github/OnTime-front/issues/593) | provider 관측 구현282db21f, 원격772 tests/87.44%·APK 통과, A15 실제 ownership 후속 로컬795 통과·기기 대기 |
| A15 | [#594](https://github.com/DevKor-github/OnTime-front/issues/594) | 요청별 후속 재조정/교체 직렬화 구현, 최종 원격795 tests/analyze·87.66%·APK 통과, 기기 대기 |
| D03 | [#595](https://github.com/DevKor-github/OnTime-front/issues/595) | 독립 journal·복구/host kill11, main통합 원격882 tests/88.50%·APK 통과,기기 대기 |
| A06 | [#598](https://github.com/DevKor-github/OnTime-front/issues/598) | d06474d4 실제 타이머 전환 구현,47경계 및 원격929전체·88.79%·APK 통과,기기 대기 |
| A07 | [#599](https://github.com/DevKor-github/OnTime-front/issues/599) | d73c7863 원자적 시작·partial retry 구현,원격944 tests/88.70%·APK 및 KOEN200% 검증,기기 대기 |
| C01 | [#600](https://github.com/DevKor-github/OnTime-front/issues/600) | 4529d9f8 백업/reset workflow 구현,959 tests·88.74%·KOEN200% 통과,A08/A09/D02 통합 대기 |
| A08 | [#601](https://github.com/DevKor-github/OnTime-front/issues/601) | 실제4문답·원자 저장/조회·충돌/멱등/소유권 기준 확정 |
| A09 | [#602](https://github.com/DevKor-github/OnTime-front/issues/602) | 실제4문답·staging/runtime 세대·복원 후 정리 기준 확정 |
| D01 | [#603](https://github.com/DevKor-github/OnTime-front/issues/603) | 실제4문답·DB 비의존 시작 복구·키/파일 보존 기준 확정 |
| D02 | [#604](https://github.com/DevKor-github/OnTime-front/issues/604) | 실제4문답·손상 DB 후보 검증/활성 쌍 교체·중단 복구 기준 확정 |
| D04 | [#605](https://github.com/DevKor-github/OnTime-front/issues/605) | 실제4문답·migration 원자성/역사 schema/SQLCipher 확인·실패 보존 기준 확정 |
| D05 | [#606](https://github.com/DevKor-github/OnTime-front/issues/606) | 실제4문답·bounded stream/자료 한도·시간대/그래프 검증 기준 확정 |
| U08 | [#597](https://github.com/DevKor-github/OnTime-front/issues/597) | 홈 overflow 선행 수정18 tests/analyze 통과, 전체 매트릭스·기기 검증 미완료 |
| A10 | [#608](https://github.com/DevKor-github/OnTime-front/issues/608) | 실제4문답·civil/instant·오늘/달력·DST·명시 zone 편집·tzdb 변경 확인 계약,32개 검증 시나리오 확정 |
| U02 | [#609](https://github.com/DevKor-github/OnTime-front/issues/609) | 실제3문답·오프라인 zone 선택/기기 환산·DST/변경 재검토,23개 검증 시나리오 확정 |
| C08 | [#610](https://github.com/DevKor-github/OnTime-front/issues/610) | 실제3문답·현재 instant/세션보존/수명주기 갱신·오류/제한 구분,32개 검증 시나리오 확정 |
| U01 | [#611](https://github.com/DevKor-github/OnTime-front/issues/611) | 실제3문답·이력 단일삭제/공유원문·점수보존/취소ownership,32개 검증 시나리오 확정 |
| U03 | [#612](https://github.com/DevKor-github/OnTime-front/issues/612) | 실제3문답·최신 토글의도/저장-OS반영 구분/화면이탈·세대 경계,28개 검증 시나리오 확정 |
| T03 | [#613](https://github.com/DevKor-github/OnTime-front/issues/613) | 실제3문답·실패경계22/암호문12행렬·기존증거 재사용/실제저장소·새프로세스 검증 계약 |
| T04 | [#614](https://github.com/DevKor-github/OnTime-front/issues/614) | 실제3문답·실제 진입점/독립 oracle·Auth 복구/삭제/세션 연결30개 검증 계약 |
| T01 | [#615](https://github.com/DevKor-github/OnTime-front/issues/615) | 실제3문답·정상main/암호화저장소·OS수신/프로세스재실행·양플랫폼18개 E2E 행렬 |
| T02 | [#616](https://github.com/DevKor-github/OnTime-front/issues/616) | 실제3문답·native15/플랫폼물리20행렬·OS경계/기기격리·실행증거 계약 |
| R02 | [#617](https://github.com/DevKor-github/OnTime-front/issues/617) | 실제3문답·동일 PR 소스 양모바일 build/native/smoke·최소권한/실패판정·12행 CI 검증 |
| R04 | [#618](https://github.com/DevKor-github/OnTime-front/issues/618) | 동일 품질 재사용·검증 AAB와 전송 바이트 연결, 16개 검증 행렬과 실제 3문답 확정 |
| R01 | [#619](https://github.com/DevKor-github/OnTime-front/issues/619) | 실제 3문답·비활성 ruleset 재사용/최신 소스 검사·독립 리뷰·15개 검증 행렬 확정 |

현재 Draft PR은 [#585](https://github.com/DevKor-github/OnTime-front/pull/585)다. 상세 이슈 **33/64개**를 게시하고 원격 본문 동일성을 확인했으며 **31개는 생성 전**이다. A12 최종 원격707 tests·APK, A13 후속 수정 최종 원격740 tests·coverage87.20%·APK가 통과했다. A14는282db21f로 전달했다. A15는ecd04293로 커밋했고 최종 로컬795 tests/analyze 및 실제 ownership/lifecycle/mutation 회귀를 통과했다. 최종 원격795 tests/analyze·87.66% 및 APK를 확인했고 D03 구현을 시작했다. D05와 A10까지 실제 문답과 백업·복구·시간대 검증 설계가 확정됐으며 D03은 독립 리뷰 보완 및 host kill11 후 최신 main 통합 원격882 tests/88.50%·APK를 통과했고 기기 검증이 남았다. A06은d06474d4로 구현해 최종929 tests/88.74%·신규47경계를 통과했고 원격929 tests/88.79%·APK도 통과했다. A07은d73c7863로 구현해 실제 DB 회귀/전체944 tests·88.67%·KOEN200% 및 원격944/88.70%·APK를 통과했고 C01 구현을 시작했다. U08 홈 overflow 선행 수정은 포함됐지만 전체 매트릭스와 기기 검증은 남아 있다. 자동 검증·이슈 개설·병합·실제 제품 완료를 구별하며 미실행 수용 조건이 있는 이슈는 열어 둔다.

## 실행 순서

| 순서 | 항목 | 우선순위 | 내용 |
|---|---|---|---|
| 1 | A01 | P0 | Android 예약 알림의 실제 수신 receiver 선언이 빠졌다. 예약 호출과 앱 registry가 성공해도 OS가 예약 시각에 호출할 수신 컴포넌트가 없다. 자체 NativeAlarmReceiver는 플러그인의 receiver를 대신하지 않는다. |
| 2 | A02 | P0 | Android/iOS 백업 내보내기가 해당 플랫폼에서 미지원인 `getSaveLocation()`을 사용한다. 암호화 성공 뒤 파일 저장 단계에서 실패하는 경로다. |
| 3 | A03 | P1 | iOS 백업 복원 picker에 필요한 `uniformTypeIdentifiers`가 없다. 현재 타입 그룹은 extensions/mimeTypes만 있어 iOS 구현이 ArgumentError를 던진다. |
| 4 | A04 | P1 | 프로필 전체 upsert가 알림 enabled를 true, 상세 표시를 false, revision을 0으로 덮어쓴다. 기본 여유시간 수정이나 일정 완료의 점수 갱신도 이 경로를 거친다. 사용자 설정과 백업 상태가 다른 작업 때문에 바뀐다. |
| 5 | A05 | P1 | 상세 알림을 OFF해도 기존 예약 알림의 내용을 바꾸지 않을 수 있다. 재등록 비교가 시간과 fingerprint/version만 보고 표시 내용·상세 설정을 무시한다. 잠금화면에 기존 일정명이 남을 수 있다. |
| 6 | A11 | P1 | 암호화 DB 밖에 준비 이름이 평문으로 남는다. cacheFingerprint가 hash가 아니라 준비 이름을 이어 붙인 문자열이고 알림 registry와 payload에 복제된다. |
| 7 | A12 | P1 | 앱 종료 상태에서 일반 알림 탭으로 시작할 때 대상 일정이 유실될 수 있다. 실행 중 callback만 등록하고 플러그인의 launch details를 읽지 않는다. 자체 native launch payload는 별도 경로다. |
| 8 | A13 | P1 | Android가 정확 알림 권한과 무관하게 항상 inexact 모드로 예약한다. full-screen alarm 지원과 정확한 notification timing을 같은 capability로 다루고 있다. |
| 9 | A14 | P1 | 기존 provider의 지원 여부만 확인해 예약을 유지한다. 현재 권한 철회/허용과 deliveryPolicy의 activeProvider, 실제 OS pending 상태가 반영되지 않는다. AlarmKit 권한 철회 후 fallback으로 바뀌지 않거나 사라진 예약을 armed로 표시할 수 있다. |
| 10 | A15 | P1 | 재등록 실행 중 들어온 새 요청은 기존 Future에 합류만 한다. 기존 작업이 일정을 읽은 뒤 새 일정이 저장되면 후속 실행 없이 오래된 예약 결과가 최종 상태로 남을 수 있다. |
| 11 | D03 | P1 | 초기화뿐 아니라 개별/전체 알림 취소·reconcile에서 취소 실패를 무시하고 registry를 지운다. OS 예약이 남아도 다음 실행은 취소할 기록을 잃는다. 기존 테스트 일부도 실패 후 빈 registry를 정상으로 고정한다. |
| 12 | A06 | P1 | 준비 단계 자동 변경 알림이 실제 1초 타이머 경로와 연결되지 않았다. 정상 타이머는 refresh 이벤트를 보내는데 단계 변경 알림은 ScheduleTick 처리에서만 발생한다. 기존 테스트는 다른 이벤트를 직접 주입한다. |
| 13 | A07 | P1 | 준비 시작 ID를 DB 쓰기 전에 성공 목록에 넣는다. 첫 저장 실패 시 제거하지 않아 같은 실행 중 재시도가 no-op이 된다. |
| 14 | C01 | P1 | 저장/복원/초기화를 domain workflow와 data transaction으로 묶고 UI는 결과만 받도록 한다. |
| 15 | A08 | P1 | 일정과 준비 단계 저장이 하나의 transaction이 아니다. 두 번째 저장 실패 시 일정만 바뀌었지만 UI는 실패를 표시한다. 일정 저장 직후 알림 reconciliation도 시작하므로 부분 상태를 읽는 경쟁 가능성이 있다. |
| 16 | A09 | P1 | 복원은 DB만 교체하고 기존 timed preparation/early start SharedPreferences와 메모리 세션을 비우지 않는다. 동일 ID·fingerprint를 복원하면 백업에서 제외되어야 할 이전 진행 상태를 재사용할 수 있다. |
| 17 | D01 | P1 | bootstrap 실패가 runApp 이전에 나면 복구 화면에도 진입하지 못한다. secure storage·파일 정리 실패를 제한된 복구 상태로 전달해야 한다. |
| 18 | D02 | P1 | 복구 화면은 재시도와 전체 삭제만 제공한다. ADR가 약속한 백업 복원 경로가 없으며 정상 DB를 요구하는 현재 restore로는 손상 DB 복구도 해결되지 않는다. reset 예외도 화면에서 처리하지 않는다. |
| 19 | D04 | P1 | 현재 v1→v2는 존재한다. DDL/version 원자성, 미래 버전 거부, 역사 fixture, SQLCipher loader/guard 및 실패 보존을 보강한다. |
| 20 | D05 | P1 | 복원 전 전체 파일을 readAsBytes하고 복호화 결과·JSON도 모두 메모리에 올린다. frame 수 상한은 있지만 총 파일 크기·총 레코드/문자열의 제품 한도가 없다. timezone ID는 비어 있지 않은지만 확인한다. |
| 21 | A10 | P1 | 절대시각과 표시용 civil time 사용이 혼재한다. 준비 시작은 occurrenceInstantUtc를 쓰지만 화면 카운트다운·지난 일정 판정 일부는 scheduleTime을 직접 쓴다. 다른 시간대 이동 시 남은 시간/진행 대상이 달라질 수 있다. |
| 22 | U02 | P1 | 일정 시간대 선택과 다른 기기 시간대에서의 환산 시각을 표시한다. |
| 23 | C08 | P1 | 가장 가까운 일정의 조회 범위를 날짜 변경·resume에 맞춰 갱신한다. |
| 24 | U01 | P1 | 완료 이력도 개별 삭제 가능하게 한다. |
| 25 | U03 | P1 | 상세 알림 토글의 로딩/저장/재등록 실패와 연속 조작을 처리한다. |
| 26 | T03 | P1 | 실패·복원·재시도 테스트를 우선한다. |
| 27 | T04 | P1 | 실제 이벤트 경로를 테스트하고 잘못된 동작을 고정한 기대값을 수정한다. |
| 28 | T01 | P1 | 핵심 실제 app E2E를 추가한다. 현재 integration_test 디렉터리가 없고 iOS RunnerTests는 testExample placeholder다. |
| 29 | T02 | P1 | 네이티브 계약 테스트와 실기기 매트릭스를 분리한다. |
| 30 | R02 | P1 | 일반 PR CI는 Ubuntu의 Dart analyze/test뿐이다. Android build는 수동 deploy, iOS build workflow는 없다. Swift/Kotlin·plugin/manifest 결함을 일찍 잡기 어렵다. |
| 31 | R04 | P1 | Android deploy는 analyze/test를 다시 하지만 coverage gate는 없다. main 보호도 없어 검사 수준이 경로마다 다르다. |
| 32 | R01 | P1 | main 보호와 effective rules가 없다. 검사 성공이 병합의 필수 조건이 아니다. |
| 33 | R09 | P1 | no-network 체크는 소스 문자열/일부 설정 검사다. 통과만으로 final APK/IPA의 전체 SDK·merged manifest·runtime traffic을 증명하지 못한다. |
| 34 | O01 | P1 | README와 Architecture/Smoke Test/Monitoring 문서가 제거된 서버·로그인·FCM·Firebase를 현재 기능처럼 설명한다. Release-Checklist는 generated Dart를 commit하라는 문장도 남아 AGENTS와 충돌한다. |
| 35 | O02 | P1 | Data Safety 문서가 기존 계정·FCM·원격 analytics와 계정 삭제 URL을 설명한다. 현재 binary와 store 신고가 일치하는지는 확인해야 한다. |
| 36 | D06 | P2 | 백업 알림의 30일 기준이 마지막 변경일이다. 계속 쓰는 사용자는 오래된 미백업 변경이 있어도 매번 기한이 밀린다. 현재 알림은 My Data 내부에만 있고 dismiss 상태도 없다. |
| 37 | D07 | P2 | 템플릿 백업의 createdAt을 읽지만 복원할 때 updatedAt만 put(now)으로 전달한다. 빈 DB 삽입 시 createdAt이 updatedAt으로 바뀌어 정렬·원본 메타데이터가 달라진다. |
| 38 | U04 | P2 | 정확히 1시간·2시간의 결과가 0분으로 표시되는 오류를 수정한다. |
| 39 | U05 | P2 | 영어 locale에서 한국어가 섞이는 설정·준비·결과·백업·오류 문구를 정리한다. |
| 40 | U06 | P2 | 여러 단계 일정 작성/수정의 미저장 이탈을 보호한다. |
| 41 | U07 | P2 | 아이콘 이름, swipe/drag 대체 조작, 입력 필드 라벨을 보완한다. |
| 42 | U08 | P2 | 글자 200%, 작은 화면, 긴 이름에서 타이머·결과·상세 화면 레이아웃을 확인한다. |
| 43 | U09 | P2 | 오류·빈 상태에 행동을 제공한다. |
| 44 | C02 | P2 | 전체 이력 구독 후 메모리 필터를 기간 SQL 조회로 바꿀지 계측한다. |
| 45 | C03 | P2 | 백업 snapshot과 템플릿 로드의 N+1 조회를 batch/join으로 줄인다. |
| 46 | C04 | P2 | 준비 시간 계산을 단일 순수 도메인 계산기로 정리한다. 실제 구현을 복사한 테스트 fake도 줄인다. |
| 47 | C05 | P2 | 값만 전달하는 use case·사용되지 않는 local data source를 정리한다. |
| 48 | C06 | P2 | controller/stream 수명과 오래된 이름을 정리한다. |
| 49 | C07 | P2 | 일관된 로컬 개발 환경을 제공한다. |
| 50 | T05 | P2 | 모듈별·변경 코드별 coverage와 미포함 파일 목록을 본다. |
| 51 | T06 | P2 | 접근성·현지화·성능 회귀 예산을 둔다. |
| 52 | R03 | P2 | Widgetbook deploy workflow는 테스트 workflow와 독립적으로 main push/PR에서 실행한다. quality 실패여도 카탈로그가 배포될 수 있다. |
| 53 | R05 | P2 | workflow concurrency/timeout 설정이 없고 Android 두 workflow가 동일 Play app/track 자원을 겹쳐 수정할 수 있다. staging 환경 보호도 없다. |
| 54 | R06 | P2 | `npm install --no-save --no-package-lock googleapis`로 매번 가변 버전을 설치하고 action refs도 tag 기반이다. Widgetbook은 checkout@v3/setup-java@v1을 쓴다. |
| 55 | R07 | P2 | Play upload는 edit commit 응답을 출력하고 끝난다. 새 edit로 track/versionCode를 재조회하지 않고 기존 releases 보존 정책도 명시하지 않는다. |
| 56 | R08 | P2 | AAB artifact 14일 보관은 있으나 SHA·version·digest·테스트·store 상태를 묶는 release manifest와 일관된 iOS 절차가 없다. docs는 production tag flow를 설명하지만 구현된 workflow는 수동 Android draft/Widgetbook뿐이다. |
| 57 | O03 | P2 | production AppLogger는 비활성인데 운영 문서는 Firebase crash/FCM 관찰을 전제한다. local-only에 맞는 진단·지원 절차가 부족하다. |
| 58 | O04 | P2 | backlog에 #518 analytics, #458 account deletion, #426 login 등 현재 제품 방향과 충돌하거나 오래된 이슈가 열려 있다. #392 migration/#397 native QA/#535 구조 개선은 재평가 가치가 있다. |
| 59 | O05 | P2 | 출시 운영 책임과 중단 기준을 local-only 기준으로 다시 쓴다. |
| 60 | F01 | P3 | 반복 일정과 일정 복제 |
| 61 | F02 | P3 | 일정 이력 검색과 필터 |
| 62 | F03 | P3 | 알림 상태 진단 |
| 63 | F04 | P3 | 백업 안내 개선 |
| 64 | F05 | P3 | 로컬 준비 패턴 요약 |
