# C01 최신 구현 준비 메모

2026-09-24 root read-only 조사. 제품 기준 e6c1438e/문서7a6825f7, A07 WIP는 전담 agent 소유이며 본 메모는 구현 완료 근거가 아니다. 상세 계약과 실제 문답은 issues/C01.md 및 #600이 권위다.

- 최신 MyDataScreen 경로는 lib/presentation/my_page/my_data_screen.dart이다. concrete BackupService/LocalDataResetService/ReconcileAlarmsUseCase를 계속 직접 호출한다. `_loadFreshness` 예외 상태가 없고 원문 오류 문구·한국어 고정 문구가 남는다.
- D03가 reset 단계를 이미 구현했다. core/database/local_reset_protocol.dart의 LocalResetResult와 LocalDataResetService/journal을 재사용한다. LocalResetProgressScreen(operation, initialResult)은 typed receipt를 표시하며 timeout은 owner를 취소하지 않는다. 별도 삭제 coordinator를 만들지 않는다.
- LocalDataRecoveryScreen도 D03에서 typed reset receipt/partial progress로 바뀌었다. C01 baseline의 예외 처리 부재를 현재 결함으로 그대로 반복하지 않고 최신 코드에서 UI 의존성 분리 gap만 확인한다.
- ScheduleMutationAlarmEffectsCoordinator는 durable commit 뒤 synchronous reconcile 접수를 보장하지만 Future<void>로 후속 receipt를 전달하지 않는다. A15 접수/후속 drain과 실제 OS owner는 유지하고 C01 결과에 commit/delivery 상태를 잃지 않게 연결한다.
- LocalDataOperationGate는 run 진입 시 replacesData이면 generation을 먼저 올린다. C01 preview token 재검사에서 자기 generation 증가를 stale로 간주하지 않는 claim 경계가 필요하며 실제 staging/replacement는 A09와 연결한다.
- C01은 실제 화면→workflow 적용을 구현하되 A08 aggregate transaction/A09 staging-runtime/D02 손상 DB restore 통합 AC를 미구현 상태에서 완료로 닫지 않는다. 현재 메모리 BackupCandidate를 verified staging이라고 이름만 바꾸지 않는다.
- A07 API/실제 검증이 동결되면 최신 결과 및 알림 owner를 다시 읽고 구현한다. source/codegen/Flutter 실행은 A07 전담이 끝난 뒤 순서대로 진행한다.

원격 PR 본문 갱신은 자동 승인 검토가 2026-09-24 명시 payload/destination 승인이 부족하다는 이유로 거절하여 사용자 응답을 기다린다. 준비 본문은 /tmp/ontime-audit-pr.md, 대상은 DevKor-github/OnTime-front Draft PR #585이다. 이 제한은 거절된 PR 본문 갱신에만 적용하며 다른 승인된 구현·이슈 업무를 중단하지 않는다. 우회/간접 게시 금지.
