# Figma v3 화면을 Flutter에 반영

기준: FIdR6bUMHScn9FWbwqrBsA 원본 26개 화면(2026-09-23 교체 완료), docs/design/redesign-20260923/original-replacement.

- 공통 화면 헤더, 하단 액션, 선택 카드, 정보 패널을 기존 위젯과 색상 토큰으로 구현한다.
- 반복 설정(단위/주간/월간/종료), 날짜·시간, 준비과정, 검토(충돌/분리/시각 선택/오류), 관리/상세/빈 상태/종료/회차를 실제 상태에 연결한다.
- 마이페이지 그룹과 복구/초기화/완료/개인정보 화면을 같은 패턴으로 맞춘다.
- 디자인의 날짜/시간/스위치 예시는 테스트 fixture로만 사용하며 실제 데이터와 기본값은 유지한다.
- 기기 상태 표시줄은 운영체제가 소유한다. 본문은 스크롤, 액션은 하단 고정, 큰 글자/좁은 화면에서 잘리지 않도록 구성한다.
- 생성 파일을 갱신하고 analyzer 및 관련 동작 테스트를 실행한다. 실제 Flutter 렌더를 저장해 Figma와 대조한다.

## 완료 결과

- 26개 Figma 상태를 기존 Flutter 경로에 반영하고 화면별 코드 지도를 작성했다.
- Flutter 위젯 렌더 26개, 화면 모음 7개, Figma 비교판 7개를 `docs/design/redesign-20260923/flutter/`에 저장했다.
- `flutter analyze --no-pub`: No issues found.
- 최종 `flutter test --no-pub --concurrency=1 --dart-define=CAPTURE_RECURRING_SCREENSHOTS=true`: 603개 모두 통과.
- `git diff --check` 통과. 개인정보 본문 6개 단락이 기존과 동일함을 확인했다.
- 앱 글꼴/운영체제 시스템 영역/초기화 후 재시작 생명주기에 대한 적용 차이는 결과 README에 기록했다.
