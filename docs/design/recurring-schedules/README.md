# 반복 일정 Figma 설계

제품 정책 21개와 오프라인 전용 제약을 반영했다. Figma 화면 21개, 요일 선택 컴포넌트 3개 상태, 주요 프로토타입 이동 18개를 추가한 뒤 Flutter 기능과 화면을 연결했다. Figma 프로토타입과 실행 코드의 검증은 아래에서 구분한다.

## Figma

- [생성·회차 관리 보드](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2110-2405)
- [마이페이지 관리 보드](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2110-21269)
- [요일 선택 컴포넌트](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-253)

## 재사용과 제약

- 기존 OnTime 시트 헤더, 입력 필드, 선택 행, 준비 단계, 버튼 인스턴스 및 색상·간격 토큰을 재사용했다. 신규 전역 변수·텍스트 스타일은 없다.
- 앱 Pretendard를 원격 Figma 환경에서 사용할 수 없어 사용자의 명시 동의 아래 기존 Noto Sans KR/IBM Plex Sans KR을 사용했다. 앱 글꼴은 바꾸지 않는다.
- 생성 화면은 단계 내부의 콘텐츠 설계다. 실제 앱에서는 기존 4단계 시트에 통합하며 장소·이동 단계는 유지한다. 프로토타입의 날짜·시간 → 준비 이동은 반복 관련 화면의 검토용 단축 이동이다.
- 18개 링크는 설정·관리의 주요 이동을 설명하는 프로토타입이다. 데이터 저장, 요일 선택 상태 변화, 날짜 계산은 Flutter 구현·테스트 대상이며 Figma에서 동작하는 기능으로 주장하지 않는다.
- SaveError 프레임은 입력 조건 오류와 기기 저장 실패 메시지를 함께 비교하는 상태 사양이다. 실제 화면에서는 원인에 해당하는 메시지만 표시한다.
- 매년 반복과 사용자 커스텀 템플릿 라이브러리 UI는 이번 범위에 포함하지 않는다.

## 검증

- 생성 보드 16개 및 관리 보드 5개 화면 원격 읽기와 스크린샷 확인.
- 생성 화면 겹침 0건, 내용이 있는 텍스트의 너비 0건 0개.
- 요일 버튼 3개 상태 모두 44×44 크기와 변수 연결 확인.
- 주요 이동 18개가 Figma 노드에 저장된 것을 다시 읽어 확인.
- 결정 20·21을 반영하여 Scope/Detached의 남은 횟수·분리 차감 문구를 보완하고 원격 read-back 및 Detached 화면 시각 검증을 완료했다. 해당 보완은 기존 노드 ID를 유지한다.

## 화면 인덱스

| 화면 | Figma 노드 |
|---|---|
| DateTime | [2112:2394](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-2394) |
| Weekly | [2112:21323](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21323) |
| Monthly | [2112:21352](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21352) |
| Ending | [2112:21395](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21395) |
| Preparation | [2112:21456](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21456) |
| Review | [2112:21500](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21500) |
| Conflicts | [2112:21531](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21531) |
| PersistentConflict | [2112:21557](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21557) |
| Scope | [2112:21588](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21588) |
| Detached | [2112:21613](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21613) |
| TimeExceptions | [2112:21635](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21635) |
| SaveError | [2112:21659](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21659) |
| Management | [2112:21676](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21676) |
| Detail | [2112:21715](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21715) |
| Empty | [2112:21756](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21756) |
| Occurrence | [2112:21768](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2112-21768) |
| Frequency | [2113:21627](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2113-21627) |
| MonthlyFields | [2113:21670](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2113-21670) |
| EndDate | [2113:21708](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2113-21708) |
| EndConfirm | [2113:21745](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2113-21745) |
| MyPageEntry | [2113:21761](https://www.figma.com/design/FIdR6bUMHScn9FWbwqrBsA/OnTime-Design-System?node-id=2113-21761) |

## Flutter 구현 검증

- `lib/presentation/recurring/` 및 기존 생성 4단계·달력·마이페이지에 연결했다. 날짜·시간 → 장소·이동 → 전용 준비과정 → 저장 전 검토로 이어진다.
- 실제 앱의 Pretendard와 기존 테마/헤더/버튼을 재사용한다. 버튼 텍스트에도 지정 글꼴이 일관되게 적용되도록 공통 TextTheme의 family를 명시했다.
- 390×844 렌더와 1.6배 글자 설정, 요일 44×44 터치 영역, 검토의 명시 제외, 관리 종료 후 다시 읽기를 위젯 테스트로 검증한다.
- DB·마이그레이션·백업·규칙·폼 연결 테스트는 계획 문서의 검증 표를 따른다.
- 최종 `flutter test --concurrency=2`: **591개 전부 통과**(2026-09-23). `flutter analyze`: **No issues found**. `git diff --check` 통과.
- `dart run build_runner build --delete-conflicting-outputs` 성공. 생성 Dart 파일은 ignored 산출물로 유지한다. 현재 생성기는 해당 옵션을 무시한다는 경고와 기존 analyzer/SDK 버전 차이 경고를 출력했으며 생성·분석·테스트는 성공했다.
- 실제 `ScheduleMultiPageForm` 4단계 위젯 → 검토 모달 → 확인 → 로컬 DB 저장을 연결해 검증했다. 검토 취소 시 무기록, 기본 준비 변경 후 전용 준비/알림 후보 유지, 오류 수정 후 재시도도 확인했다.
- 이후 수정으로 분리된 독립 일정의 원래 날짜가 새 규칙에 다시 포함되는 경우를 추가 검증했다. 독립 일정은 유지되며 새 구간 회차와 식별자가 충돌하지 않는다.
- 후속으로 실제 DB → 알림 등록부 → 재조정을 연결한 통합 테스트 3개도 통과했다. 두 무기한 묶음의 전역 60개 한도, 삭제 후 취소·보충·미재생, 음수 UTC 오프셋 날짜 경계를 검증했다. 추가 후 분석도 이상 없다.
- iOS 26.5 전용 시뮬레이터에서 빌드·신규 설치·4단계 생성·저장·강제 종료 후 재실행을 확인했다. 기본 준비를 4분으로 바꾼 뒤에도 반복 전용 준비는 3분을 유지했다. [실행 결과와 실제 시뮬레이터 캡처](implementation/native-ios/README.md).
- 원격 Figma의 Weekly/Monthly/Review/Scope/Management 설계 문맥을 읽고 기존 토큰·요소와 비교했다. 아래 4개 Flutter 렌더의 텍스트/간격/터치 영역을 직접 확인했다.
- 실제 iOS/Android 기기의 알림 전달·권한·재부팅·장기 미실행 보충은 아직 직접 실행하지 않았다. 로컬 저장/알림 후보 테스트 성공과 실제 전달 성공은 구분한다.

앱 렌더: [주간 반복 설정](implementation/weekly.png), [월간 반복 설정](implementation/monthly.png), [저장 전 확인](implementation/review.png), [반복 관리](implementation/management.png). 위젯 렌더 캡처이며 실제 기기 캡처는 아니다.
