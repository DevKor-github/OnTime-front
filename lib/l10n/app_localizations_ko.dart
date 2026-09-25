// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get detailedNotificationTitle => '알림에 일정 이름 표시';

  @override
  String get detailedNotificationPrivacy =>
      '잠금화면에 일정 이름과 다른 시간대만 표시합니다. 장소, 메모, 준비 내용은 표시하지 않습니다.';

  @override
  String get detailedNotificationLoading => '설정 확인 중';

  @override
  String get detailedNotificationReadFailed => '설정을 불러오지 못했습니다. 저장된 값을 확인해주세요.';

  @override
  String get detailedNotificationUnavailable =>
      '로컬 데이터 변경이 끝난 뒤 설정을 다시 확인해주세요.';

  @override
  String get detailedNotificationRequestOn => '켬 요청 중 · 아직 저장되지 않음';

  @override
  String get detailedNotificationRequestOff => '끔 요청 중 · 아직 저장되지 않음';

  @override
  String get detailedNotificationSavedOn => '켬으로 저장됨';

  @override
  String get detailedNotificationSavedOff => '끔으로 저장됨';

  @override
  String get detailedNotificationSaveFailed =>
      '요청한 변경을 저장하지 못했습니다. 아직 적용되지 않았습니다.';

  @override
  String get detailedNotificationApplying => '저장된 설정을 알림에 반영 중';

  @override
  String get detailedNotificationDelayed =>
      '기기의 응답이 늦어지고 있습니다. 알림 적용을 계속 확인 중입니다.';

  @override
  String get detailedNotificationApplied => '현재 알림 등록에 반영됨';

  @override
  String get detailedNotificationOff => '일정 알림이 꺼져 있습니다.';

  @override
  String get detailedNotificationEmpty => '현재 반영할 예정 알림이 없습니다.';

  @override
  String get detailedNotificationPermission => '알림 권한을 확인해주세요. 저장된 설정은 유지됩니다.';

  @override
  String get detailedNotificationCancellation =>
      '기존 알림에 일정 이름이 남아 있을 수 있습니다. 알림 정리를 다시 확인해주세요.';

  @override
  String get detailedNotificationSchedulingFailed =>
      '일부 알림을 예약하지 못했습니다. 알림을 다시 적용해주세요.';

  @override
  String get detailedNotificationNeedsCheck =>
      '알림 적용 여부를 확인하지 못했습니다. 다시 확인해주세요.';

  @override
  String get detailedNotificationHeld =>
      '끔 요청이 해결될 때까지 새 상세 알림 등록을 보류합니다. 기존 알림이 제거됐다는 뜻은 아닙니다.';

  @override
  String get detailedNotificationRetry => '다시 확인·적용';

  @override
  String get startupRecoveryTitle => '앱을 시작할 수 없습니다';

  @override
  String get startupRecoveryBody =>
      '로컬 데이터를 확인하는 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get startupRetryAction => '다시 시도';

  @override
  String get restartRequiredBody => '앱을 완전히 닫은 뒤 다시 열어 주세요.';

  @override
  String get resetInProgressTitle => '로컬 데이터 초기화 중';

  @override
  String get resetInProgressBody => '알림과 로컬 데이터의 정리 상태를 확인하고 있습니다.';

  @override
  String get resetWaitingBody =>
      '기기의 알림 작업 응답을 기다리고 있습니다. 아직 초기화가 완료되지 않았습니다. 앱을 다시 열면 정리를 이어갑니다.';

  @override
  String get resetDeletedPendingBody =>
      '기기 내 데이터는 삭제됐지만 일부 알림 정리는 아직 확인되지 않았습니다.';

  @override
  String get resetIncompleteBody => '초기화가 끝나지 않았습니다. 확인되지 않은 정리 단계만 다시 시도합니다.';

  @override
  String get resetNoIntentBody => '초기화 기록을 확인하지 못해 완료로 처리하지 않았습니다. 다시 시도해 주세요.';

  @override
  String get resetCompleteTitle => '로컬 데이터 초기화 완료';

  @override
  String get resetCompleteBody =>
      '로컬 데이터와 알림 정리를 확인했습니다. 새로 시작하려면 앱을 완전히 닫고 다시 열어 주세요.';

  @override
  String get resetRetryAction => '정리 다시 시도';

  @override
  String get notificationCleanupNeededStatus => '꺼짐 · 알림 취소 확인 필요';

  @override
  String get calendarTitle => '캘린더';

  @override
  String get error => '오류';

  @override
  String get retry => '다시 시도';

  @override
  String get preparationInProgress => '준비 진행 중';

  @override
  String get noSchedules => '약속이 없어요';

  @override
  String get setSpareTimeTitle => '여유시간을 설정해주세요';

  @override
  String get setSpareTimeDescription => '설정한 여유시간만큼 일찍 도착할 수 있어요.';

  @override
  String get setSpareTimeWarning => '여유시간은 혹시 모를 상황을 위해 꼭 설정해야 돼요.';

  @override
  String get spareTimeMinimumWarning => '여유시간은 10분 아래로 설정할 수 없어요';

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
  String get allowAlarms => '알람 허용하기';

  @override
  String get doItLater => '나중에 할게요.';

  @override
  String get pleaseAllowNotifications => '알림을 허용해주세요';

  @override
  String get notificationPermissionDescription =>
      '약속 준비 리마인더를 보내\n제시간에 준비할 수 있게 도와드려요.';

  @override
  String get allowPreciseNotifications => '정확한 알림 허용하기';

  @override
  String get pleaseAllowAlarms => '알람을 허용해주세요';

  @override
  String get alarmPermissionDescription =>
      '앱이 닫혀 있어도 약속 준비를 제시간에 시작할 수 있도록 알람을 사용해요.';

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
  String get preparationCompletedTitle => '모든 준비를 마쳤어요!';

  @override
  String get preparationCompletedDescription =>
      '준비 단계를 모두 완료했어요.\n지금 종료하거나 계속 준비할 수 있어요.';

  @override
  String get continuePreparing => '계속 준비';

  @override
  String get finishPreparation => '준비 종료';

  @override
  String get finishPreparationConfirmTitle => '준비가 모두 끝나셨나요?';

  @override
  String get finishPreparationConfirmDescription =>
      '준비 종료를 누르면\n준비를 마치고 결과를 확인할 수 있어요.';

  @override
  String get preparationReadyToGo => '출발 준비 완료';

  @override
  String get signInSlogan => '당신의 잃어버린 여유를 찾아드립니다.';

  @override
  String get signInFailedTitle => '로그인에 실패했어요';

  @override
  String get signInFailedDescription => '잠시 후 다시 시도해 주세요.';

  @override
  String get welcome => '반가워요!';

  @override
  String get onboardingStartSubtitle =>
      'Ontime과 함께 준비하기 위해서\n평소 본인의 준비 과정을 알려주세요';

  @override
  String get start => '시작하기';

  @override
  String get preparationOrderTitle => '앞에서 고른 준비 과정의 순서를\n설정해주세요';

  @override
  String get preparationNameTitle => '약속에 나가기 위한 준비 과정을\n선택해주세요 ';

  @override
  String get multipleSelection => '(복수 선택)';

  @override
  String get preparationTimeTitle => '과정별로 소요되는 시간을\n알려주세요';

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
  String get preparationTime => '준비시간';

  @override
  String get preparationNameRequired => '준비 이름을 입력해 주세요.';

  @override
  String get preparationTimeMinimumError => '준비 시간을 1분 이상으로 설정해 주세요.';

  @override
  String preparationTimeMaximumError(int minutes) {
    return '준비 시간은 최대 $minutes분까지 설정할 수 있어요.';
  }

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
  String get startPreparingNow => '지금 준비 시작';

  @override
  String get notNow => '나중에';

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
  String get editPreparationSpareTimeHeader => '여유시간/준비과정 수정';

  @override
  String get done => '완료';

  @override
  String get addPreparationStep => '준비 과정 추가';

  @override
  String get allowAppNotifications => '앱 알림 허용';

  @override
  String get helpImproveOnTime => 'OnTime 개선에 참여';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get privacyPolicyOpenError => '개인정보 처리방침을 열 수 없습니다. 잠시 후 다시 시도해주세요.';

  @override
  String get logOut => '로그아웃';

  @override
  String get deleteAccount => '회원 탈퇴';

  @override
  String get editSpareTime => '여유시간 수정';

  @override
  String get editPreparationTime => '준비 과정 및 시간 수정';

  @override
  String get totalTime => '총 시간: ';

  @override
  String scheduleOverlapWarning(int minutes, String scheduleName) {
    return '\"$scheduleName\"과 겹치지 않으려면 $minutes분 안에 준비해야해요';
  }

  @override
  String scheduleOverlapError(String scheduleName, String startTime) {
    return '다음 일정 $scheduleName과 겹쳤어요! 다음 일정 준비 시작시간은 $startTime이에요';
  }

  @override
  String get scheduleTimePastError => '미래의 약속 시간을 선택해주세요.';

  @override
  String previousScheduleOverlapError(int minutes, String scheduleName) {
    return '\"$scheduleName\"과 겹쳤어요! $minutes분 더 빨리 준비해야 해요';
  }

  @override
  String get logOutConfirm => '로그아웃 하시겠어요?';

  @override
  String get deleteAccountConfirmTitle => '정말 탈퇴하시나요?';

  @override
  String get deleteAccountConfirmDescription =>
      '현재 로그인한 계정의 탈퇴를 요청합니다.\n탈퇴가 완료되면 로그아웃됩니다.';

  @override
  String get keepUsing => '계속 사용할게요';

  @override
  String get deleteAnyway => '그래도 탈퇴할게요';

  @override
  String get scheduleDeleteConfirmTitle => '정말 약속을 삭제할까요?';

  @override
  String get scheduleDeleteConfirmDescription => '약속을 삭제하면 다시 되돌릴 수 없어요.';

  @override
  String get deleteScheduleConfirmAction => '약속 삭제';

  @override
  String get scheduleDeleteFailedTitle => '약속을 삭제할 수 없어요';

  @override
  String get scheduleDeleteFailedDescription =>
      '이 약속은 더 이상 삭제할 수 없어요. 상태가 방금 바뀐 경우 캘린더를 새로고침한 뒤 다시 확인해주세요.';

  @override
  String get deleteFeedbackTitle => '더 좋은 서비스로 다시 만나요';

  @override
  String get deleteFeedbackDescription =>
      '의견 입력은 선택 사항입니다.\n계속 진행하면 계정 탈퇴 요청이 전송됩니다.';

  @override
  String get deleteFeedbackPlaceholder => '탈퇴하시는 이유를 알려주세요.';

  @override
  String get keepUsingLong => '탈퇴하지 않고 계속 사용하기';

  @override
  String get sendFeedbackAndDelete => '의견 보내고 탈퇴하기';

  @override
  String get preparationStartsInFiveMinutes =>
      '5분 뒤에 준비가 시작돼요.\n미리 준비를 시작하시겠어요?';

  @override
  String preparationStartsEarlyBy(String duration) {
    return '$duration 일찍 준비를 시작할 수 있어요.\n지금 미리 준비를 시작할까요?';
  }

  @override
  String get preparationStartsLaterStartEarly =>
      '조금 일찍 준비를 시작할 수 있어요.\n지금 미리 준비를 시작할까요?';

  @override
  String get continuePreparingNext => '이어서 준비하세요';

  @override
  String get notificationAlreadyEnabled => '알림이 이미 허용됨';

  @override
  String get notificationAlreadyEnabledDescription =>
      '약속 준비 리마인더가 현재 활성화되어 있습니다.';

  @override
  String get notificationPermissionRequired => '알림 권한 필요';

  @override
  String get notificationPermissionRequiredDescription =>
      '온타임은 약속 준비 리마인더와 약속 알림을 보내기 위해 알림을 사용합니다.\n알림을 허용하시겠습니까?';

  @override
  String get allow => '허용';

  @override
  String get notificationPermissionGranted => '알림 허용 완료';

  @override
  String get notificationPermissionGrantedDescription =>
      '약속 준비 리마인더가 활성화되었습니다.';

  @override
  String get openNotificationSettings => '설정에서 알림 허용';

  @override
  String get openNotificationSettingsDescription =>
      '알림 권한이 거부되었습니다.\n약속 준비 리마인더를 받으려면 설정에서 알림을 허용해주세요.';

  @override
  String get preciseNotificationPermissionRequired => '정확한 알림 권한이 필요해요';

  @override
  String get preciseNotificationPermissionDescription =>
      '정확한 시간에 준비를 알려드리기 위해 이 권한이 필요해요.';

  @override
  String get scheduleNotificationSetting => '일정 알림';

  @override
  String get alarmStatus => '알람';

  @override
  String get preciseNotificationStatus => '정확한 알림';

  @override
  String get notificationStatus => '알림';

  @override
  String get noScheduledNotificationStatus => '예정된 알림 없음';

  @override
  String get notificationPermissionNeededStatus => '알림 권한 필요';

  @override
  String get exactAlarmPermissionRequired => '정확한 알림 권한이 필요해요';

  @override
  String get exactAlarmPermissionRequiredDescription =>
      '정확한 시간에 준비를 알려드리기 위해 이 권한이 필요해요.\nAndroid 설정에서 알람 및 리마인더를 허용해주세요.';

  @override
  String get openSettings => '설정 열기';

  @override
  String get notificationTimingEducationTitle => '준비 시작 알림을 더 정확하게';

  @override
  String get notificationTimingEducationDescription =>
      '현재 알림은 켜져 있으며 준비 시작 시각보다 늦게 도착할 수 있어요. 정확한 시각 권한을 허용하면 더 정확하게 예약할 수 있어요. OS, 절전 설정과 기기 상태에 따라 도착이 늦어질 수 있습니다.';

  @override
  String get notificationTimingAvailable => '정확한 시각 예약 가능';

  @override
  String get notificationTimingApproximate => '근사 시각 예약 · 정확한 시각 설정 가능';

  @override
  String get notificationApproximateStatus => '알림 · 근사 시각';

  @override
  String get notificationMixedTimingStatus => '알림 · 일부 근사 시각';

  @override
  String get notificationIncompleteStatus => '알림 예약 일부 실패 또는 확인 필요';

  @override
  String get notificationTimingSettings => '정확한 시각 설정하기';

  @override
  String get startupLoadingBody => '기기에 저장된 데이터를 확인하고 있습니다.';

  @override
  String get startupWaitingBody => '기기의 응답을 기다리고 있습니다. 확인이 끝날 때까지 잠시 기다려 주세요.';

  @override
  String get preparationStartFailed => '준비 시작을 저장하지 못했어요. 다시 시도해주세요.';

  @override
  String get preparationStartPartial =>
      '준비는 시작했지만 진행 저장 또는 알림 정리가 일부 완료되지 않았어요.';

  @override
  String get dataTitle => '내 데이터';

  @override
  String get dataBackupStatus => '백업 상태';

  @override
  String get dataReminder => '30일 이상 백업되지 않은 변경 사항이 있습니다.';

  @override
  String get dataExport => '암호화 백업 내보내기';

  @override
  String get dataExportDescription => '선택한 파일 위치에만 저장합니다.';

  @override
  String get dataRestore => '백업에서 복원';

  @override
  String get dataRestoreDescription => '미리 확인한 뒤 현재 데이터를 완전히 교체합니다.';

  @override
  String get dataReset => '로컬 데이터 초기화';

  @override
  String get dataResetDescription => '이 기기의 OnTime 데이터와 알람을 모두 삭제합니다.';

  @override
  String get dataChecking => '확인 중';

  @override
  String get dataNeverExported => '아직 내보낸 백업이 없습니다.';

  @override
  String get dataNoChanges => '마지막 백업 이후 변경 사항이 없습니다.';

  @override
  String get dataUnexportedChanges => '백업되지 않은 변경 사항이 있습니다.';

  @override
  String get dataFreshnessFailed => '백업 상태를 확인하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get dataRetry => '다시 시도';

  @override
  String get dataRetryDelivery => '알림 처리만 다시 시도';

  @override
  String get dataRestoreCleanupPending =>
      '데이터는 복원됐지만 남은 정리와 알림 처리가 완료되지 않았습니다. 데이터를 다시 복원하지 않고 남은 처리만 다시 시도할 수 있습니다.';

  @override
  String get dataRetryCleanup => '남은 처리 다시 시도';

  @override
  String get dataRestorePartial =>
      '데이터는 복원됐지만 알림 처리가 완료되지 않았습니다. 알림 처리만 다시 시도할 수 있습니다.';

  @override
  String get dataUncommittedCleanup =>
      '데이터는 복원되지 않았습니다. 이미 시작된 알림 정리를 마무리하려면 현재 데이터의 알림 처리를 다시 시도해 주세요.';

  @override
  String get dataExportSaved => '암호화 백업을 저장했습니다.';

  @override
  String get dataExportMetadataFailed =>
      '파일은 저장됐지만 백업 상태를 갱신하지 못했습니다. 백업 상태 확인만 다시 시도해 주세요.';

  @override
  String get dataRestoreComplete => '백업을 복원했습니다.';

  @override
  String get dataDeliveryUpdated => '현재 데이터의 알림 처리를 완료했습니다.';

  @override
  String get dataBusy => '다른 데이터 작업이 진행 중입니다. 완료 후 다시 시도해 주세요.';

  @override
  String get dataUnavailable => '로컬 데이터를 사용할 수 없습니다. 앱을 다시 열어 주세요.';

  @override
  String get dataStalePreview => '미리보기 이후 데이터가 변경됐습니다. 백업을 다시 선택하고 확인해 주세요.';

  @override
  String get dataInvalidBackup => '작업을 완료하지 못했습니다. 백업 파일과 비밀번호를 확인해 주세요.';

  @override
  String get dataStagingCleanupFailed =>
      '데이터는 복원되지 않았고 임시 파일 정리가 완료되지 않았습니다. 앱을 다시 열면 정리를 다시 시도합니다.';

  @override
  String get dataOperationFailed => '작업을 완료하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get dataRestorePreviewTitle => '복원 내용 확인';

  @override
  String get dataRestoreAction => '복원';

  @override
  String get dataCancel => '취소';

  @override
  String get dataContinue => '계속';

  @override
  String get dataCreatePassword => '백업 비밀번호 만들기';

  @override
  String get dataEnterPassword => '백업 비밀번호 입력';

  @override
  String get dataPassword => '백업 비밀번호';

  @override
  String get dataPasswordHelp => '15~128자, 대소문자와 공백을 그대로 구분합니다.';

  @override
  String get dataConfirmPassword => '백업 비밀번호 확인';

  @override
  String get dataPasswordMismatch => '비밀번호가 서로 다릅니다.';

  @override
  String get dataPasswordInvalid => '백업 비밀번호는 15~128자로 입력해주세요.';

  @override
  String dataRestorePreview(
    String cutoff,
    String version,
    String platform,
    int schedules,
    int templates,
    int steps,
  ) {
    return '백업 시점: $cutoff\n앱 버전: $version\n원본 플랫폼: $platform\n일정 $schedules개\n준비 템플릿 $templates개\n기본 준비 단계 $steps개\n\n현재 로컬 데이터는 모두 교체됩니다.';
  }

  @override
  String get dataResetFailed => '초기화하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get scheduleSavedPending => '일정은 저장됐어요';

  @override
  String get scheduleDeliveryPendingBody =>
      '알림 업데이트를 완료하지 못했어요. 다시 시도하면 저장한 일정은 그대로 두고 알림만 업데이트합니다.';

  @override
  String get scheduleSaveConflict => '저장 전에 변경 사항을 확인해 주세요';

  @override
  String get scheduleSaveConflictBody =>
      '화면을 연 뒤 로컬 데이터가 바뀌었어요. 입력은 유지됩니다. 새 일정은 다른 데이터가 바뀌어도 다시 확인해야 합니다.';

  @override
  String get scheduleReviewCurrent => '현재 데이터 확인';

  @override
  String get scheduleCreateReview =>
      '현재 로컬 데이터를 기준으로 새 저장을 준비합니다. 입력 내용을 확인한 뒤 저장 버튼을 다시 눌러 주세요.';

  @override
  String get scheduleDraftPreserved =>
      '위 내용은 현재 저장된 일정입니다. 확인하면 입력한 초안을 유지하며 새 저장을 준비합니다. 변경 내용을 검토한 뒤 저장을 다시 눌러 주세요.';

  @override
  String get scheduleSaveProtected =>
      '이미 시작됐거나 준비 시간이 지난 일정은 수정할 수 없어요. 입력 내용은 유지됩니다.';

  @override
  String get scheduleSaveUnavailable =>
      '저장할 수 없어요. 입력을 유지했으니 현재 상태와 준비 단계를 확인해 주세요.';

  @override
  String get defaultPreferencesLoadFailed => '설정을 불러오지 못했어요. 다시 불러와 주세요.';

  @override
  String get defaultPreferencesSaveFailed =>
      '설정을 저장하지 못했어요. 입력은 그대로 남아 있어요. 다시 시도해 주세요.';

  @override
  String get defaultPreferencesInvalid =>
      '준비 이름과 시간, 여유 시간을 확인해 주세요. 설정은 저장되지 않았어요.';

  @override
  String get defaultPreferencesConflict =>
      '편집 중 일정 또는 설정이 변경되었어요. 입력은 남아 있지만 아직 저장되지 않았어요. 최신 설정을 다시 불러온 뒤 확인해 주세요.';

  @override
  String get defaultPreferencesReloadPending =>
      '설정은 저장되었지만 화면 갱신을 마치지 못했어요. 다시 저장하지 않고 화면 갱신만 재시도할 수 있어요.';

  @override
  String get defaultPreferencesDeliveryPending =>
      '설정은 저장되었지만 알림 처리를 마치지 못했어요. 다시 저장하지 않고 알림 처리만 재시도할 수 있어요.';

  @override
  String get defaultPreferencesBothPending =>
      '설정은 저장되었지만 화면 갱신과 알림 처리를 마치지 못했어요. 다시 저장하지 않고 남은 작업만 재시도할 수 있어요.';

  @override
  String get defaultPreferencesSavedStoreChanged =>
      '설정을 저장한 뒤 로컬 작업 상태가 달라졌어요. 이 화면의 작업은 다시 실행하지 않아요. 화면을 닫고 현재 설정을 확인해 주세요.';

  @override
  String get defaultPreferencesRetryFollowUp => '남은 작업 다시 시도';

  @override
  String get defaultPreferencesLoadLatest => '최신 설정 다시 불러오기';

  @override
  String get defaultPreferencesDiscardTitle => '편집 내용을 버리고 다시 불러올까요?';

  @override
  String get defaultPreferencesDiscardDescription =>
      '최신 설정을 불러오면 이 화면의 저장하지 않은 편집 내용이 바뀌어요. 불러오지 못하면 편집 내용은 유지돼요.';

  @override
  String defaultPreferencesMinutes(int minutes) {
    return '$minutes분';
  }

  @override
  String get defaultPreferencesAuthorityPending =>
      '설정은 저장되었지만 현재 로컬 데이터를 확인하지 못했어요. 다시 저장하지 않고 남은 작업을 재시도할 수 있어요.';

  @override
  String get zonedTimeOriginal => '약속 시간';

  @override
  String get zonedTimeDevice => '기기 시간';

  @override
  String get zonedTimeDeviceLoading => '기기 시간대를 확인하고 있어요.';

  @override
  String get zonedTimeDeviceUnavailable => '기기 시간대를 확인할 수 없어 환산 시각을 표시하지 못해요.';

  @override
  String get zonedTimeDeviceOutOfRange =>
      '기기 환산 날짜가 지원 범위를 벗어나요. 원래 약속 시간은 유지됩니다.';

  @override
  String get zonedTimeUnknownZone => '시간대를 확인해주세요.';

  @override
  String get zonedTimeHistoricalUnknownZone =>
      '이 기록의 시간대 규칙을 찾을 수 없어요. 저장된 약속은 그대로 보존됩니다.';

  @override
  String get zonedTimeHistoricalUncertain =>
      '과거 기록의 발생 시각을 확정할 수 없어요. 저장된 시간은 그대로 보존됩니다.';

  @override
  String get zonedTimeNonexistent => '이 시간대에는 존재하지 않는 시각이에요. 다른 시각을 선택해주세요.';

  @override
  String get zonedTimeAmbiguous => '두 번 발생하는 시각이에요. 사용할 발생 시각을 선택해주세요.';

  @override
  String get zonedTimeRulesChanged => '시간대 규칙이 달라졌어요. 변경할 발생 시각을 확인해주세요.';

  @override
  String get zonedTimeInvalid => '약속 시간을 확인해주세요.';

  @override
  String get zonedTimeInstant => '실제 시각 (UTC)';

  @override
  String get zonedTimeChooseZone => '시간대 선택';

  @override
  String get zonedTimeSearch => '도시 또는 시간대 검색';

  @override
  String get zonedTimeClearSearch => '검색어 지우기';

  @override
  String get zonedTimeCurrentDeviceZone => '현재 기기 시간대';

  @override
  String get zonedTimeCurrentSelection => '현재 일정 시간대';

  @override
  String get zonedTimeDraftPreview => '선택 미리보기';

  @override
  String get zonedTimeKeepCivil =>
      '날짜와 시각은 유지하고 시간대를 변경해요. 저장 전 약속 시간을 다시 확인합니다.';

  @override
  String get zonedTimeNoMatches =>
      '일치하는 시간대가 없어요. 도시 이름이나 IANA 식별자로 다시 검색해주세요.';

  @override
  String get zonedTimeApplyDraft => '선택 적용';

  @override
  String get zonedTimeReviewTitle => '약속 시간 확인';

  @override
  String get zonedTimeReviewDescription => '저장할 약속과 기기에서의 시각을 확인해주세요.';

  @override
  String get zonedTimeBefore => '변경 전';

  @override
  String get zonedTimeAfter => '저장할 약속';

  @override
  String get zonedTimeConfirmSave => '확인하고 저장';

  @override
  String get zonedTimeFirstOccurrence => '첫 번째 발생';

  @override
  String get zonedTimeSecondOccurrence => '두 번째 발생';

  @override
  String get zonedTimeDetectedZone => '기기에서 확인한 시간대';

  @override
  String get zonedTimeSelectedZone => '직접 선택한 시간대';

  @override
  String get zonedTimeSavedZone => '저장된 일정 시간대';

  @override
  String get zonedTimeSelectUnavailableZone => '기기 시간대를 확인할 수 없어요. 직접 선택해주세요.';

  @override
  String get zonedTimeNextValid => '다음 유효 시각 확인';

  @override
  String get zonedTimePreparationStart => '준비 시작';

  @override
  String get zonedCityAsiaSeoul => '서울';

  @override
  String get zonedCityAsiaTokyo => '도쿄';

  @override
  String get zonedCityAsiaShanghai => '상하이';

  @override
  String get zonedCityAsiaHongKong => '홍콩';

  @override
  String get zonedCityAsiaTaipei => '타이베이';

  @override
  String get zonedCityAsiaSingapore => '싱가포르';

  @override
  String get zonedCityAsiaBangkok => '방콕';

  @override
  String get zonedCityAsiaDubai => '두바이';

  @override
  String get zonedCityAsiaKolkata => '콜카타';

  @override
  String get zonedCityAsiaKathmandu => '카트만두';

  @override
  String get zonedCityEuropeLondon => '런던';

  @override
  String get zonedCityEuropeParis => '파리';

  @override
  String get zonedCityEuropeBerlin => '베를린';

  @override
  String get zonedCityEuropeRome => '로마';

  @override
  String get zonedCityEuropeMadrid => '마드리드';

  @override
  String get zonedCityEuropeMoscow => '모스크바';

  @override
  String get zonedCityAmericaNewYork => '뉴욕';

  @override
  String get zonedCityAmericaLosAngeles => '로스앤젤레스';

  @override
  String get zonedCityAmericaChicago => '시카고';

  @override
  String get zonedCityAmericaDenver => '덴버';

  @override
  String get zonedCityAmericaToronto => '토론토';

  @override
  String get zonedCityAmericaVancouver => '밴쿠버';

  @override
  String get zonedCityAmericaSaoPaulo => '상파울루';

  @override
  String get zonedCityAustraliaSydney => '시드니';

  @override
  String get zonedCityAustraliaMelbourne => '멜버른';

  @override
  String get zonedCityAustraliaPerth => '퍼스';

  @override
  String get zonedCityAustraliaLordHowe => '로드하우';

  @override
  String get zonedCityPacificAuckland => '오클랜드';

  @override
  String get zonedCityPacificHonolulu => '호놀룰루';

  @override
  String get zonedCityPacificApia => '아피아';

  @override
  String get zonedCityAfricaCairo => '카이로';

  @override
  String get zonedCityAfricaJohannesburg => '요하네스버그';

  @override
  String get zonedCityUtc => '협정 세계시';

  @override
  String get zonedTimeHomeDateBasis => '오늘 · 기기 날짜 기준';

  @override
  String get zonedTimeCalendarDateBasis => '달력 · 원래 약속 날짜 기준';

  @override
  String get zonedTimeDateBasisTitle => '날짜가 다른 이유';

  @override
  String get zonedTimeDateBasisDescription =>
      '홈의 오늘 일정은 현재 기기 시간대의 날짜로 모읍니다. 월 달력은 각 약속의 원래 시간대와 날짜에 배치합니다. 약속과 기기 시간대가 다르면 같은 순간이 서로 다른 날짜일 수 있어 두 날짜와 시간대를 함께 표시합니다.';

  @override
  String get zonedTimeAllReviewedOccurrences => '검토 중인 회차 모두 보기';

  @override
  String get zonedTimeReviewScopeOccurrence => '변경 범위: 이번 회차';

  @override
  String get zonedTimeReviewScopeFollowing => '변경 범위: 이번 회차와 이후';

  @override
  String get zonedTimeReviewScopeNew => '새 반복 일정';

  @override
  String get zonedTimePreparationUnavailable =>
      '현재 시간대 규칙으로 준비 시작을 표시할 수 없어요. 저장 전에 다시 검토해주세요.';

  @override
  String get homeNextAppointment => '다음 약속';

  @override
  String get homePreparationInProgress => '진행 중인 준비';

  @override
  String get homePreparationPrompt => '준비할 약속';

  @override
  String get homePreviouslyCheckedAppointment => '이전에 확인한 약속';

  @override
  String get homeCheckingAppointments => '다음 약속을 확인하고 있어요.';

  @override
  String get homeNoUpcomingAppointments => '예정된 약속이 없어요.';

  @override
  String get homeQueryFailed => '약속을 확인하지 못했어요. 다시 시도해 주세요.';

  @override
  String get homeQueryCancelled => '약속 확인을 중단했어요. 캘린더에서 약속을 확인할 수 있어요.';

  @override
  String get homeQueryInterrupted => '약속 확인이 중단됐어요. 이어서 확인해 주세요.';

  @override
  String get homeQueryLimited => '모든 약속을 확인하지 못했어요. 캘린더에서 약속이나 반복 설정을 확인해 주세요.';

  @override
  String get homeQueryStale =>
      '아래는 이전에 확인한 내용이에요. 다시 확인하기 전에는 이 카드에서 준비를 시작할 수 없어요.';

  @override
  String get homeRetryQuery => '다시 확인';

  @override
  String get homeContinueQuery => '이어서 확인';

  @override
  String get homeCancelQuery => '확인 중단';

  @override
  String get homeTimeIssues =>
      '시간을 확인해야 하는 약속이 있어요. 캘린더에서 해당 약속의 날짜와 시간대를 검토해 주세요.';

  @override
  String get homeReviewCalendar => '캘린더에서 확인';

  @override
  String get scheduleDeletionRemovedTitle => '일정 이력이 삭제됐어요';

  @override
  String get scheduleDeletionComplete => '일정 이력과 알림 정리가 완료됐어요.';

  @override
  String get scheduleDeletionCleaning => '이력은 삭제됐고 알림을 정리하고 있어요.';

  @override
  String get scheduleDeletionPending =>
      '이력은 삭제됐지만 알림 정리가 아직 확인되지 않았어요. 정리가 끝나면 다시 확인할 수 있어요.';

  @override
  String get scheduleDeletionPreparationActive =>
      '준비가 진행 중이에요. 준비 화면에서 먼저 종료한 뒤 삭제해 주세요.';

  @override
  String get scheduleDeletionConsequences =>
      '선택한 일정의 이름, 메모, 개별 준비와 결과를 삭제해요. 다른 일정과 공유 중인 내용 및 이미 반영된 시간 엄수 점수는 유지돼요. 앱에서 실행 취소할 수 없으며, 이전에 내보낸 백업을 복원하면 이력이 다시 나타날 수 있어요.';

  @override
  String get scheduleDeletionFollowing => '선택한 회차와 이후의 미진행 회차를 삭제해요.';

  @override
  String get scheduleDeletionOnlySelected =>
      '선택한 일정만 삭제해요. 다른 일정과 반복 규칙은 유지돼요.';

  @override
  String get scheduleDeletionAlreadyAbsent =>
      '이 일정은 현재 데이터에 이미 없어요. 새로 삭제한 데이터는 없어요.';

  @override
  String get scheduleDeletionRetryCleanup => '알림 정리 다시 확인';

  @override
  String get scheduleDeletionAbsentTitle => '이미 없는 일정';

  @override
  String get scheduleDeletionFollowingConsequences =>
      '이 반복 일정의 선택한 회차부터 이후 미진행 회차를 삭제하고, 이후 반복 생성을 종료해요. 개별로 수정한 이후 회차도 삭제 대상에 포함돼요. 삭제 대상의 이름, 메모와 다른 일정에서 공유하지 않는 준비 내용을 삭제해요. 과거 이력, 진행 중이거나 준비가 고정된 회차, 다른 반복 일정, 공유 중인 내용과 이미 반영된 시간 엄수 점수는 유지돼요. 앱에서 실행 취소할 수 없어요. 이미 내보낸 백업 파일은 바뀌지 않으며, 이전 백업을 복원하면 삭제한 회차와 반복이 다시 나타날 수 있어요.';
}
