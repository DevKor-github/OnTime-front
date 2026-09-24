# C01 구현 검토 실제 문답

기존 grill-with-docs 3문답은 issues/C01.md에 보존되어 있다. 아래는 구현 중 실제 추가 질문/검토와 답변이다.

## 구현 담당의 writer/claim 의존 조사

> C01 적용 경계에서 한 가지 구현 의존을 확인했습니다. 현재 일반 durable writer는 LocalDataOperationGate에 참여하지 않아 gate 내부에서 revision을 읽은 뒤 await 알림 취소 동안 편집이 들어올 수 있습니다. C01에서 generation/revision token과 단일 claim을 추가하고, DB transaction 시작 시 revision을 다시 검사해 durable 교체를 막는 것은 가능합니다. 다만 stale 후에도 이미 실행한 알림 취소를 없던 일로 만들 수 없으므로 A09의 runtime/replacement 순서까지 완전 충족이라고 주장하면 안 됩니다. 권고: C01은 claim 전검사 + DB transaction 안 최종 revision 검사/부분상태를 구현하고, 검증된 staging 및 모든 일반 writer와 replacement fencing은 A09 통합 미완료로 명시합니다. 원본 데이터 stale overwrite는 막고 OS 정리가 이미 발생한 경우 후속 reconcile 필요 사실을 결과에 보존하겠습니다. 이 경계로 진행하겠습니다(새 제품정책이 아니라 기존 AC의 미충족 부분 명시).

## Root 답변

> 이 경계로 진행하되 완전한 C01 stale-before-side-effects AC는 미완료로 명시하세요. 최소한 claim 이전 generation/revision 부적합이면 OS/runtime/data 변경0이어야 하고, claim 이후 일반 writer가 들어온 경우 DB transaction 안 최종 revision 재검사로 원본overwrite 방지. 이미 수행한 OS취소/세대변경은 typed receipt에 남기고 현재 데이터의 명시/기존 reconcile 복구로 이어야 하며 단순 stale=no-op이라고 보고하면 안 됩니다. DB tx 안 nativeawait 금지 유지. 결정적 barrier로 preview→claim 사이 변경과 OS취소대기중일반편집→최종tx rejection 두경로 실제Drift 검증. A09에 모든writer fencing/staging/runtime순서 통합을 명시해 C01닫지않음. 이 실제 구현 의존 질문/권고/답변 원문을 /tmp/c01-review-transcript.md에 보존해주세요.

## Root retry/receipt 검토

> root WIP 리뷰: BackupWorkflow._retry 단일 Future가 receipt/generation 구별 없이 공유되면 이전 restore의 느린 retry 중 새 generation의 다른 receipt 재시도가 이전 결과를 받을 수 있습니다. retry는 operation identity+generation 기준 singleflight로 묶고 과거 receipt가 새 작업의 후속으로 잘못 합류하지 않게 해주세요. 같은 token의 동시 apply 합류와 commit 후 재제출(재적용 금지)의 typed 결과도 별도 테스트. _completed Expando의 과거 pending receipt를 retry 성공 후 다시 읽을 때 pending이 계속 남는지도 확인 필요합니다. 아직 WIP임은 알고 있으며 final 전에 위 경계 확인 부탁합니다.

> 또한 _restore의 await _backup.apply(input) 뒤 generation getter를 읽어 committedGeneration으로 쓰면, commit 이후 반환 직전에 다른 replacement/reset이 generation을 바꾼 경우 이전 commit을 새 세대 receipt로 잘못 귀속할 수 있습니다. adapter apply가 실제 claim/commit generation을 반환하는 immutable receipt를 사용하고 후속 currentness는 그 receipt 기준으로 검사하는 편이 안전합니다. 에러 catch에서도 '현재 generation'을 이전 부분작업의 generation처럼 기록하지 않도록 시작/claim identity 구별. deterministic after-commit/before-workflow-continuation gate change 회귀 부탁합니다.

## 구현 담당 답변

> 리뷰 2개 반영 중입니다. retry singleflight는 receipt 객체별 Expando로 바꿨고, commit 직후 아직 delivery 대기 중인 동일 token은 completed보다 pending Future를 우선 공유합니다. BackupOperationsPort.apply는 claim이 발급한 정확한 generation을 반환하도록 바꾸며 catch 부분 결과에도 claim generation을 보존합니다. retry 완료 시 약한 참조로 연결된 token의 cached receipt도 갱신해 오래된 pending을 반복 반환하지 않겠습니다. 초기 회귀에서는 비밀번호 dialog 뒤 busy spinner 때문에 pumpAndSettle이 끝나지 않는 UI 상태를 발견해 입력대기와 실제 IO 표시를 분리했습니다.

## Root UI currentness 검토

> 추가 UI currentness 리뷰: _loadFreshness 성공에는 generation 검사지만 catch에는 없고, _export/_restore catch도 _routeCurrent만 검사하므로 같은 route에서 세대 변경 후 늦은 old error가 새 화면에 표시될 수 있습니다. 실패 경로에도 operation 시작/claim receipt의 currentness를 적용해주세요. _resetData confirmation 대기에는 _busy가 false이고 확인 뒤 mounted만 확인하므로 확인화면 중복/대상세대변경 경계도 확인. reset은 성공적 invalidate 자체를 stale로 오인하면 안 되니 destructive acceptance 전 확인토큰과 결과표시소유권을 구별해주세요. 기존root검토와함께 transcript 보존 부탁합니다.

## 구현 담당 반영

freshness/export/preview 실패 경로에 시작 generation 검사를 적용했다. reset은 확인 화면을 열기 전 busy를 획득하고, 확인 직후 route 및 기존 generation을 검사한 다음 명시 reset을 접수한다. 실제 reset 결과는 자체 invalidate를 실패로 오인하지 않는다. old error/freshness/disposed route 회귀를 추가했다.
