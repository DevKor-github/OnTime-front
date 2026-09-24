# Figma v3 → Flutter 반영

2026-09-23 원본 교체가 끝난 Figma 26개 화면의 레이아웃과 상태를 기존 Flutter 경로에 반영했다. 데이터 생성·반복 계산·저장·백업의 도메인 동작과 기본값은 유지한다.

## 적용 내용

- 기존 `TopBar`, `ModalWideButton`, `StepProgress`, 색상 토큰을 확장해 중앙 헤더, 하단 고정 액션, 번호 단계, 선택·정보 카드를 구성했다. 주색은 기존 blue600, 보조색은 blue200을 사용한다.
- 반복 단위, 주간 요일, 월간 규칙, 종료 날짜/횟수에 실제 폼 상태를 연결했다. 월간 순번과 마지막 요일을 분리해 선택할 수 있다.
- 검토의 예정 회차/충돌/영구 충돌/분리 일정/서머타임/저장 오류를 원인별로 표시한다. 모든 회차 제외 시 저장 금지, 독립 준비과정, 기존 데이터 보존을 유지한다.
- 반복 관리의 카드/빈 상태/상세/종료 확인과 달력에서 여는 회차 상세를 연결했다. 지난 회차의 편집 제한은 기존 정책을 따른다.
- 준비 목록의 순서 변경과 기존 준비 편집 화면을 연결하고, 총 준비 시간에서 여유 시간을 제외한다.
- 마이페이지를 알림·시간·일정·데이터·기타로 묶었다. 값은 실제 use case/운영체제 권한에서 읽으며 백업·복원·초기화 항목은 기존 동작으로 연결된다.
- 복구 경고/초기화 확인/처리 중/실패/완료 및 개인정보 6개 조항을 적용했다. 복구 경고와 완료 표식은 Figma SVG를 로컬 asset으로 사용한다.

## 검증과 시각 자료

- `flutter analyze --no-pub`: 오류 없음.
- 이 디렉터리의 [validation.txt](validation.txt)는 2026-09-23 첫 반영 시점의 기록이다. 메인 화면 갱신을 병합한 뒤 최신 테스트와 비교 범위는 [QA handoff](../../../../handoff/ios-ui-quality-figma-parity.md)와 [화면 매핑](../../figma_code_map.yaml)을 확인한다.
- 390×844 Flutter 위젯 렌더 26개를 아래에 저장했다. 실제 iOS/Android 기기 캡처가 아니다. 테스트의 날짜·준비 단계·설정값은 fixture이며 제품 기본값을 바꾸지 않는다.
- 320px 너비와 글자 1.6배에서 반복·복구 관련 상태를 검사하고, 긴 하단 액션은 필요 시 세로 배치한다.
- `comparison-*.png`와 `contact-*.png`는 첫 반영 시점의 비교/모음 이미지다. 갱신된 반복 관리·빈 상태 단일 캡처는 `screenshots/management.png`, `screenshots/empty.png`이며, 최신 상태별 참조/골든은 [화면 매핑](../../figma_code_map.yaml)을 기준으로 한다.

## 적용 시 유지한 차이

- 앱은 기존 합의대로 Pretendard를 유지한다. Figma 원격 환경의 Noto Sans KR/IBM Plex Sans KR와 글자 폭이 다를 수 있다.
- 상태 표시줄과 홈 표시줄은 운영체제가 그린다. Flutter 캡처에는 가짜 9:41/배터리/홈 막대를 그리지 않는다. 생성 폼 캡처는 실제 입력 위젯을 독립 테스트 화면에 올린 것으로, 홈 배경과 모달 바깥 부분은 재현하지 않는다.
- 월간 규칙/종료 설정은 기존 폼 안의 편집 상태로 이어지며, 장소·이동을 포함한 기존 4단계를 유지한다. 데이터량·글자 크기에 따라 본문을 스크롤한다.
- 초기화 완료 후 기존 저장소가 닫히는 생명주기를 유지한다. '다시 시작 안내' 버튼은 앱을 완전히 종료한 뒤 다시 열도록 안내한다. 화면만 온보딩으로 이동해 닫힌 저장소를 재사용하지 않는다.
- 실제 기기의 권한 팝업·알림 전달·초기화 후 재실행은 이번 위젯 검증 범위에 포함하지 않았다.

## 화면과 코드

| 상태 | Figma 원본 | Flutter 코드 | 렌더 |
|---|---|---|---|
| date-time | [2112:2394](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-2394) | `lib/presentation/schedule_create/schedule_date_time/screens/schedule_date_time_form.dart` | [PNG](screenshots/date-time.png) |
| weekly | [2112:21323](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21323) | `lib/presentation/recurring/recurrence_settings_sheet.dart` | [PNG](screenshots/weekly.png) |
| monthly | [2112:21352](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21352) | `lib/presentation/recurring/recurrence_settings_sheet.dart` | [PNG](screenshots/monthly.png) |
| ending | [2112:21395](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21395) | `lib/presentation/recurring/recurrence_settings_sheet.dart` | [PNG](screenshots/ending.png) |
| preparation | [2112:21456](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21456) | `lib/presentation/schedule_create/schedule_spare_and_preparing_time/screens/schedule_spare_and_preparing_time_form.dart` | [PNG](screenshots/preparation.png) |
| review | [2112:21500](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21500) | `lib/presentation/recurring/recurrence_review_sheet.dart` | [PNG](screenshots/review.png) |
| conflicts | [2112:21531](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21531) | `lib/presentation/recurring/recurrence_review_sheet.dart` | [PNG](screenshots/conflicts.png) |
| persistent-conflict | [2112:21557](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21557) | `lib/presentation/recurring/recurrence_review_sheet.dart` | [PNG](screenshots/persistent-conflict.png) |
| scope | [2112:21588](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21588) | `lib/presentation/recurring/recurrence_scope_sheet.dart` | [PNG](screenshots/scope.png) |
| detached | [2112:21613](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21613) | `lib/presentation/recurring/recurrence_review_sheet.dart` | [PNG](screenshots/detached.png) |
| time-exceptions | [2112:21635](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21635) | `lib/presentation/recurring/recurrence_time_choice_sheet.dart` | [PNG](screenshots/time-exceptions.png) |
| save-error | [2112:21659](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21659) | `lib/presentation/recurring/recurrence_time_choice_sheet.dart` | [PNG](screenshots/save-error.png) |
| frequency | [2113:21627](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2113-21627) | `lib/presentation/recurring/recurrence_settings_sheet.dart` | [PNG](screenshots/frequency.png) |
| monthly-fields | [2113:21670](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2113-21670) | `lib/presentation/recurring/recurrence_settings_sheet.dart` | [PNG](screenshots/monthly-fields.png) |
| end-date | [2113:21708](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2113-21708) | `lib/presentation/recurring/recurrence_settings_sheet.dart` | [PNG](screenshots/end-date.png) |
| end-confirm | [2113:21745](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2113-21745) | `lib/presentation/recurring/recurring_management_screen.dart` | [PNG](screenshots/end-confirm.png) |
| management | [2112:21676](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21676) | `lib/presentation/recurring/recurring_management_screen.dart` | [PNG](screenshots/management.png) |
| detail | [2112:21715](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21715) | `lib/presentation/recurring/recurring_management_screen.dart` | [PNG](screenshots/detail.png) |
| empty | [2112:21756](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21756) | `lib/presentation/recurring/recurring_management_screen.dart` | [PNG](screenshots/empty.png) |
| occurrence | [2112:21768](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2112-21768) | `lib/presentation/recurring/recurrence_occurrence_sheet.dart` | [PNG](screenshots/occurrence.png) |
| mypage-entry | [2113:21761](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2113-21761) | `lib/presentation/my_page/my_page_screen.dart` | [PNG](screenshots/mypage-entry.png) |
| recovery | [1957:11762](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=1957-11762) | `lib/presentation/startup/screens/local_data_recovery_screen.dart` | [PNG](screenshots/recovery.png) |
| recovery-busy | [2005:12036](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2005-12036) | `lib/presentation/startup/screens/local_data_recovery_screen.dart` | [PNG](screenshots/recovery-busy.png) |
| recovery-confirm | [2003:12059](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=2003-12059) | `lib/presentation/startup/screens/local_data_recovery_screen.dart` | [PNG](screenshots/recovery-confirm.png) |
| reset-complete | [1963:11762](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=1963-11762) | `lib/presentation/my_page/my_data_screen.dart` | [PNG](screenshots/reset-complete.png) |
| privacy | [1950:11759](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA?node-id=1950-11759) | `lib/presentation/my_page/privacy_policy_screen.dart` | [PNG](screenshots/privacy.png) |
