# A07 구현 중 실제 추가 리뷰 문답

## DB 최초 시각과 Preparation Run 시각

root:
> root독립리뷰에서실제결함발견: _startEarly가 _scheduleRepository.startSchedule(...startedAt:run.startedAt)의 DateTime 반환을버리고 marker/snapshot/receipt에run.startedAt를계속사용합니다. DB가이미시작됐거나새screen/runOwner/새instance재시도면repo는기존firstStartedAt를반환하므로DB/run/timer시각이달라집니다. authoritative committed timestamp를반환값에서받아후속모든단계·receipt·projection에사용하도록수정하고, 실제DB이미startedAt=T0인상태에서새usecase/owner가T1으로재시도해T0보존하는회귀추가해주세요. _runs owner교체중이전commit과새시도가경합하는case도같은불변식. 신규첫시도실패후동일intenttimestamp유지와모순없도록candidate vs committed시각구분.

implement_a07:
> 이 지점은 A07 Q2 보충정정/Q3 최종 계약과 구별이 필요합니다. 계약: schedule.startedAt 최초 durable 사실은 보존하지만 A11 재확인 후 명시적 새 run은 독립 T1, DB T0만으로 active run 복원 금지입니다. 현재 runOwner 교체는 새 explicit intent로 취급합니다. 권고 수정: repository 반환 T0를 별도 durableStartedAt receipt로 유지; 유효한 동일 runtime/same run retry는 저장된 run.startedAt T0, 명시적 재확인/새 prompt의 새 run은 T1을 사용합니다. 새 usecase+DB T0만 있고 runtime없는 경우는 자동 T0 run 복원하지 않습니다. 이 구별 유지하면서 '유효 snapshot의 동일 run 재시도'와 '재확인 새 run' 각각 실제 DB 회귀를 추가하겠습니다. root가 의도한 새instance T0 보존은 유효 runtime 있는 동일 run에 한정하면 확정 계약과 일치합니다.

root:
> A07 Q2 보충/Q3를 재확인했고 당신의 구별이 맞습니다. 앞선 root의 DB 최초 시각을 모든 새 run에 강제하자는 제안은 철회합니다. schedule.startedAt은 durable 최초 사실 T0, 유효한 동일 run 재시도는 해당 run 시각 보존, A11 재확인 후 명시적 새 run은 T1로 유지하세요. DB T0만으로 active run 자동 복원 금지입니다. owner 교체 자체가 새 run 의도라는 근거가 되지 않도록 실제 explicit start/reconfirmation 경로를 확인하고, 유효 snapshot 동일 run 재시도와 명시적 새 run을 각각 실제 DB 회귀로 구분해주세요. 이 실제 리뷰 질문·답변·철회도 최종 A07 이슈 보충에 남기겠습니다. Flutter 독점 유지하며 검증 계속해주세요.

implement_a07:
> 시각 구별 반영했습니다: owner 교체만으로 새 run을 만들지 않고 유효 snapshot이면 기존 run 시각/skip events를 재사용하며, requiresConfirmation 또는 fingerprint 불일치면 명시적 시작 시각으로 새 run을 만듭니다. repository 반환 최초 시각은 별도 durableStartedAt receipt로 보존합니다. 실제 DB T0 + runtime T1에서 유효 재시도와 재확인 T2를 분리한 2개 회귀를 추가했습니다. 기존 UI 3개 실패는 로딩 없는/외부 async zone fixture 문제로 수정 후 통과했습니다.

## 부분 실패 표시의 수명

root:
> root 중간 리뷰: _onUpcomingReceived가 같은 active schedule의 stream 갱신에서 ScheduleState.started(...)를 새로 만들므로 hasPendingStartRecovery/isRecoveringStart가 기본 false로 사라질 가능성을 확인해주세요. DB commit 후 marker/snapshot/cancel partial → 다음 unrelated profile/schedule emission에서 pending 배너가 조용히 사라지면 안 됩니다. 같은 run refresh 중 pending 보존/실제 retry 성공 때만 해제 회귀가 필요합니다. 현재 WIP라 이미 수정 중이면 결과만 알려주세요. _runs fingerprint/validated snapshot 변경 방향은 확인했습니다.

## 실제 UI 검증의 완료 경계

root:
> 추가 리뷰: schedule_start_commit_widget_test가 실제 SQLite 대기용 40ms/20ms sleep을 쓰고 있습니다. 고정 sleep은 느린 CI에서 결과 경합하므로 observable DB/event completion latch 또는 명시 condition을 bounded watchdog으로 기다리는 helper로 교체해주세요(tester.runAsync 유지 가능). 제품 _Cancel.barrier 도달을 별도 completer로 관찰해 버튼 disabled/route-exit 순간을 확정하세요. 실패 UI도 실패 Future 완료+frame로 확인. broad pumpAndSettle은 최종 정적 화면 외 사용 최소화. UI 텍스트 신규 오류/partial배너는 KO/EN 200% 렌더/overflow와 캡처도 남겨주세요.

## 새 메모리 캐시 수명

root:
> 추가 작은 검토: use case singleton의 _runs/_projections/_starts/_epochs는 generation이 key라 오래된 결과가 새 run에 섞이지는 않지만 reset/restore 이후 이전 preparation 원문/action snapshot 참조가 계속 남을 수 있습니다. 기존 gate listener 또는 다음 public operation capture 때 이전 generation map entry를 정리하고 실제 진행중 Future owner의 안전한 완료는 유지할 수 있는지 확인해주세요. 별도 coordinator/무한cache 만들지 말고 최소 정리만; A09 전체runtime reset을 선행 완료했다는 주장 없이 A07 새 캐시 수명만 다루면 됩니다.

## listener 수명과 테스트 관찰

root:
> generation listener 추가는 확인했습니다. singleton도 getIt.reset/앱 teardown 시 _operations shared에 listener가 남으면 old repository/usecase 전체를 붙잡으므로 @disposeMethod dispose에서 removeListener 및 cache clear를 연결하고 직접 생성한 테스트도 필요한 tearDown을 맞춰주세요. live native Future는 dispose가 강제취소/owner release하지 않도록 유지.

## 확대 화면의 기존 overflow와 범위

implement_a07:
> KO/EN 200% QA에서 새 오류 확인 화면은 렌더됐지만 기존 AlarmScreen의 graph 고정 높이(190, padding100)와 PreparationStepTile 고정 높이(131)가 각각 72px/22px overflow합니다(/tmp/a07-ui-capture.log). 신규 partial 배너 자체 오류는 아닙니다. A07에서 2개 기존 컴포넌트의 텍스트 스케일 대응 최소 높이만 조정해 전체 화면 캡처까지 끝내는 방향을 권고합니다(새 디자인/전반 U03 재설계 없음). 이 작은 통합 수정으로 진행하겠습니다. 추가 범위 정책을 달리 원하면 알려주세요.

root:
> 최소 통합 수정 진행하세요. 새 partial 배너가 들어가는 실제 AlarmScreen 200% 사용 가능성은 A07 검증에 필요합니다. 해당 기존 overflow는 U08 선행 보완으로도 교차기록하고 U03(알림 설정 상태)와 혼동하지 마세요. graph/tile 내용 잘림·스크롤/배치 의미를 유지하고 수정 전 overflow 증거와 후 KO/EN 캡처를 보존. broader U08 전체완료 주장은 하지 않습니다. 59/28 focused 및 generation cache 정리 수령했고 최종 검증 기다립니다.

root:
> root가 /tmp/a07-ui/preparation-error-ko.png를 직접 봤습니다. overflow exception 없는 start error 화면도 맨 아래 파란 버튼 '준비 시작' 레이블 하단이 잘려 보입니다(고정57 height +200%텍스트). 해당 버튼도 minHeight/내용기반 높이로 최소 보완해주세요. 스크린샷 렌더후 육안 확인이 필요합니다. 기존 캐릭터/레이아웃 디자인은 유지.

root:
> 수정된 preparation-error-ko 및 partial KO/EN 캡처 육안 확인했습니다. 시작 버튼 잘림 해소, 새 오류/partial 배너 문구·재시도 표시 확인. 영어 partial 화면의 상단 시간 안내/단계 시간/skip 한국어는 기존 U05 잔여로 명시하고 이번에 전반 현지화 범위 확장하지 마세요. 200% 단계 카드가 finish 영역 아래 일부 가려 보이므로 실제 목록 스크롤로 skip/다른단계 접근 가능성만 widget 검증 부탁합니다. 배너자체는 화면 안에 들어옵니다.

implement_a07:
> 추가 검토 반영 완료: getIt @disposeMethod로 shared listener 제거·새 캐시 clear, 진행 중 owner release하지 않는 회귀 통과. DB/취소 completion latch로 고정 sleep 제거. 실제 AlarmScreen 200%에서 KO/EN 모두 목록 스크롤 후 skip 버튼 tap 및 다음 단계 hit-test 통과했습니다. 새 오류/partial 화면 PNG 4개를 /tmp/a07-ui에 다시 생성하고 모두 육안 확인했습니다. 기존 EN 화면의 한국어 시간/skip 문구는 U05 잔여로 남깁니다. 최종 focused 56개 pass, analyzer는 테스트의 hasListeners 보호 멤버 관찰 2개 경고만 명시적 test-only 설명으로 정리 중이며 이후 source freeze/full 1회 시작합니다.

root:
> 수령했습니다. root도 4캡처 중 KO error와 KO/EN partial을 직접 확인했고 새 문구/버튼 표시 이상없음 확인했습니다. 추가 root 변경 요청은 없습니다. 테스트의 보호멤버 상태 확인은 production API 확장보다 test-only 명시 ignore로 한정 가능하며 그 이유를 주석에 남겨주세요. 최종 freeze/full 진행하세요.

## ARB 최소 diff

root:
> rootWIPstat확인: ARB app_en1220줄/app_ko417줄 변경은전체JSON재직렬화로보입니다. 최종freeze전에원본정렬/들여쓰기/비ASCIIescape형식을보존하고신규키부분만최소diff로되돌려주세요(생성trackedl10n은필요한변경유지). 다른제품직접편집하지않고root문서만진행중.

implement_a07:
> ARB 전체 재직렬화는 원본 git 내용을 복원한 뒤 신규 2키만 추가하여 최소 diff로 정리했습니다. focused 초기 81 pass/3 UI 실패 확인 중입니다. 실제 DB negative 3건은 수정 뒤 통과했고 singleflight 실패·동일 시각 retry, snapshot partial 후 skip 보존, 새 generation 독립 회귀도 통과했습니다.
