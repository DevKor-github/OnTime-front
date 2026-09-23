# U08 선행 홈 패치 증거

이 폴더는 전체 U08 완료 증거가 아니다. `../../u08-home-validation.json`에 검증 당시 소스 SHA256과 이미지/로그 SHA256이 있다.

## 화면

- `u08-home-430-empty.png`: 일정 없는 홈.
- `u08-home-430-schedule.png`: 일정 있는 홈.
- 두 화면 모두 **독립 HomeScreenContent의 Flutter widget render**이다. production router screenshot이나 OS screenshot이 아니다. 전체 앱 chrome/하단 내비게이션/물리 기기 safe-area를 증명하지 않는다.
- 430×932 logical pixels, DPR 1, EN, 글자 1.0배, safe-area 0.
- 실제 Pretendard Regular/Medium/SemiBold/Bold 및 MaterialIcons를 로드하고 `home_banner.png`를 precache했다.
- MaterialApp/Scaffold를 외부에 두고 debug banner를 숨겼다. 캡처 동안만 `debugDisableShadows=false`를 적용했고 테스트 종료 전에 원래 값을 복구했다.
- 카드 높이·제목·내용, 달력과 마지막 날짜의 겹침/가림이 없음을 U08 담당자와 root가 시각 확인했다.

## 재현

제품 회귀 검증은 저장된 정상 테스트로 실행한다.

```sh
flutter test --concurrency=1 test/presentation/home/screens/home_screen_tmp_test.dart test/presentation/shared/router/notification_launch_widget_test.dart
flutter analyze lib/presentation/home/screens/home_screen_tmp.dart test/presentation/home/screens/home_screen_tmp_test.dart test/presentation/shared/router/notification_launch_widget_test.dart
```

최종 결과는 home 14 + 실제 production router 4 = **18 passed**이다. production router는 390×844/430×932, old id B/old의 4가지 경우를 실행한다. 홈의 430 화면에서 마지막 날짜를 실제 탭하여 날짜 route를 검증하고, 달력 보기/오늘 일정을 실제 탭한다. 캡처용 2 cases는 이 18개에 추가된 제품 테스트가 아니다.

PNG 재생성 시 `home_screen_tmp_test.dart`의 `430 portrait home fits actual font` 두 case를 임시 파일에 복사한다. `buildSubject`의 MaterialApp 바깥에 키가 있는 RepaintBoundary를 두고, MaterialApp builder에서 Scaffold로 child를 감싼다. banner를 precache하고 한 프레임을 그린 뒤 `tester.runAsync` 안에서 RenderRepaintBoundary.toImage(pixelRatio: 1) → Image.toByteData(ImageByteFormat.png)로 저장한다. image.dispose 및 debug shadow 복구를 수행한다. 테스트는 `--plain-name '430 portrait home'`로 두 case만 실행한다. 날짜와 schedule 시간이 fixture 생성 시각을 따르므로 재생성 PNG의 픽셀 해시는 달라질 수 있다. 당시 임시 원본은 `/tmp/u08-home-capture-test.dart`에 보존했고 제품 test 디렉터리에서는 제거했다.

## 로그

- `u08-home-red.log`: 수정 전, 실제 폰트 430×932 일정 존재 홈에서 14px overflow. 빈 홈은 통과했다.
- `u08-home-green.log`: 최종 소스의 targeted 18 passed.
- `u08-home-analyze.log`: 최종 3파일 No issues found.
- `u08-home-capture.log`: 최종 캡처용 임시 harness 2 passed.

200% 글자, 다른 화면의 전체 매트릭스, Android/iOS 실제 OS 큰 글자 검증은 미실행이다.
