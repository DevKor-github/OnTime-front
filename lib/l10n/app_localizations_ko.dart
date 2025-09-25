// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get calendarTitle => '캘린더';

  @override
  String get error => '오류';

  @override
  String get noSchedules => '일정이 없습니다';

  @override
  String get setSpareTimeTitle => '여유시간을 설정해주세요';

  @override
  String get setSpareTimeDescription => '설정한 여유시간만큼 일찍 도착할 수 있어요.';

  @override
  String get setSpareTimeWarning => '여유시간은 혹시 모를 상황을 위해 꼭 설정해야 돼요.';

  @override
  String get todaysAppointments => '오늘의 약속';

  @override
  String get slogan => '작은 준비가\n큰 여유를 만들어요!';

  @override
  String get noAppointments => '약속이 없는 날이에요';

  @override
  String get am => '오전';

  @override
  String get pm => '오후';

  @override
  String get allowNotifications => '알림 허용하기';

  @override
  String get doItLater => '나중에 할게요.';

  @override
  String get pleaseAllowNotifications => '알림을 허용해주세요';

  @override
  String get notificationPermissionDescription =>
      '알림을 허용해야 온타임이 준비를 \n도와드릴 수 있어요';

  @override
  String get late => ' 지각했어요';

  @override
  String get early => ' 일찍 준비했어요';

  @override
  String get letsGo => '까먹지 않고 출발';

  @override
  String get areYouRunningLate => '준비가 늦어졌나요?';

  @override
  String get runningLateDescription =>
      '아직 준비가 늦었다면 남아서 계속 준비하세요.\n하지만 늦을 지도 몰라요!';

  @override
  String get continuePreparing => '계속 준비';

  @override
  String get finishPreparation => '준비 종료';

  @override
  String get signInSlogan => '당신의 잃어버린 여유를 찾아드립니다.';

  @override
  String get welcome => '반가워요!';

  @override
  String get onboardingStartSubtitle =>
      'Ontime과 함께 준비하기 위해서\n평소 본인의 준비 과정을 알려주세요';

  @override
  String get start => '시작하기';

  @override
  String get preparationOrderTitle => '앞에서 고른 준비 과정의 순서를\n알려주세요';

  @override
  String get preparationNameTitle => '주로 하는 준비 과정을\n선택해주세요 ';

  @override
  String get multipleSelection => '(복수 선택)';

  @override
  String get preparationTimeTitle => '준비 시간';

  @override
  String get addAppointment => '약속 추가하기';

  @override
  String get next => '다음';

  @override
  String get appointmentName => '약속 이름';

  @override
  String get appointmentNameHint => '예) 영화 보기';

  @override
  String get appointmentPlace => '약속 장소';

  @override
  String get travelTime => '이동시간';

  @override
  String get hours => '시간';

  @override
  String get minutes => '분';

  @override
  String get selectTime => '시간을 선택해 주세요';

  @override
  String get appointmentTime => '약속 시간';

  @override
  String get enterDate => '날짜를 입력해주세요.';

  @override
  String get enterTime => '시간을 입력해주세요.';

  @override
  String get thisWeeksAppointments => '이번 주 약속';

  @override
  String get viewCalendar => '캘린더 보기';

  @override
  String points(int score) {
    return '$score점';
  }

  @override
  String punctualityComment(int score) {
    return '성실도 점수 $score점 올랐어요!\n약속을 잘 지키고 있네요';
  }

  @override
  String get movingScreenTitle => '이동중 화면입니다';

  @override
  String get cancel => '취소';

  @override
  String get ok => '확인';

  @override
  String get youWillBeLate => '지금 준비 시작 안하면 늦어요!';

  @override
  String get startPreparing => '준비 시작';

  @override
  String get confirmLeave => '정말 나가시겠어요?';

  @override
  String get confirmLeaveDescription => '이 화면을 나가면\n함께 약속을 준비할 수 없게 돼요';

  @override
  String get leave => '나갈래요';

  @override
  String get stay => '있을래요';

  @override
  String get untilAppointment => '약속까지';

  @override
  String get appName => 'OnTime';

  @override
  String get spareTime => '여유시간';

  @override
  String get home => '홈';

  @override
  String get myPage => '마이';

  @override
  String get plus => '플러스';

  @override
  String get schedule => '일정';

  @override
  String hourFormatted(int count) {
    return '$count시간';
  }

  @override
  String minuteFormatted(int count) {
    return '$count분';
  }

  @override
  String get myPageTitle => '마이페이지';

  @override
  String get myAccount => '내 계정';

  @override
  String get appSettings => '앱 설정';

  @override
  String get accountSettings => '계정 설정';

  @override
  String get editDefaultPreparation => '기본 준비과정 / 여유시간 수정';

  @override
  String get allowAppNotifications => '앱 알림 허용';

  @override
  String get logOut => '로그아웃';

  @override
  String get deleteAccount => '회원 탈퇴';

  @override
  String get editSpareTime => '여유시간 수정';

  @override
  String get editPreparationTime => '준비시간 수정';

  @override
  String get totalTime => '총 시간: ';

  @override
  String get logOutConfirm => '로그아웃 하시겠어요?';

  @override
  String get deleteAccountConfirmTitle => '정말 탈퇴하시나요?';

  @override
  String get deleteAccountConfirmDescription =>
      '계속 온타임과 준비를 함께하면\n지각을 60% 줄일 수 있어요.';

  @override
  String get keepUsing => '계속 사용할게요';

  @override
  String get deleteAnyway => '그래도 탈퇴할게요';

  @override
  String get deleteFeedbackTitle => '더 좋은 서비스로 다시 만나요';

  @override
  String get deleteFeedbackDescription =>
      '더 나은 온타임이 될 수 있도록,\n어떤 점이 불편하셨는지\n알려주시면 감사하겠습니다.';

  @override
  String get deleteFeedbackPlaceholder => '탈퇴하시는 이유를 알려주세요.';

  @override
  String get keepUsingLong => '탈퇴하지 않고 계속 사용하기';

  @override
  String get sendFeedbackAndDelete => '의견 보내고 탈퇴하기';
}
