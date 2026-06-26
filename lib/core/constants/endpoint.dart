import 'dart:core';

class Endpoint {
  //user
  static const _signIn = '/login';
  static const _signUp = '/sign-up';
  static const _signInWithGoogle = '/oauth2/google/login';
  static const _signInWithApple = '/oauth2/apple/login';
  static const _getUser = '/users/me';
  static const _deleteGoogleMe = '/oauth2/google/me';
  static const _deleteAppleMe = '/oauth2/apple/me';
  static const _feedback = '/feedback';
  static const _deleteUser = '/users/me/delete';
  static const _analyticsPreference = '/users/me/analytics-preference';

  static String get signIn => _signIn;
  static String get signUp => _signUp;
  static String get signInWithGoogle => _signInWithGoogle;
  static String get signInWithApple => _signInWithApple;
  static String get getUser => _getUser;
  static String get deleteGoogleMe => _deleteGoogleMe;
  static String get deleteAppleMe => _deleteAppleMe;
  static String get feedback => _feedback;
  static String get deleteUser => _deleteUser;
  static String get analyticsPreference => _analyticsPreference;

  // schedule
  static const _schedules = '/schedules';

  static String getScheduleById(String scheduleId) => '$_schedules/$scheduleId';
  static String get getSchedulesByDate => _schedules;

  static String get createSchedule => _schedules;
  static String updateSchedule(String scheduleId) => '$_schedules/$scheduleId';
  static String deleteScheduleById(String scheduleId) =>
      '$_schedules/$scheduleId';
  static String startSchedule(String scheduleId) =>
      '$_schedules/$scheduleId/start';
  static String finishSchedule(String scheduleId) =>
      '$_schedules/$scheduleId/finish';

  // preparation
  static const _createDefaultPreparation =
      '$_getUser/onboarding'; // 사용자 준비과정 첫 세팅

  static const _defaultPreparation = '/users/preparations'; // 사용자 기본 준비과정 조회

  static String get createDefaultPreparation => _createDefaultPreparation;

  static String _prepartionByScheduleId(String scheduleId) =>
      '$_schedules/$scheduleId/preparations';

  static String getCreateCustomPreparation(String scheduleId) =>
      _prepartionByScheduleId(scheduleId);

  static String getPreparationByScheduleId(String scheduleId) =>
      _prepartionByScheduleId(scheduleId);

  static String updatePreparationByScheduleId(String scheduleId) =>
      _prepartionByScheduleId(scheduleId);

  static String get getDefaultPreparation => _defaultPreparation;

  static String get updateDefaultPreparation => _defaultPreparation;

  static const _preparationTemplates = '/preparation-templates';

  static String get preparationTemplates => _preparationTemplates;

  static String preparationTemplateById(String templateId) =>
      '$_preparationTemplates/$templateId';

  static const _updateSpareTime = '/users/me/spare-time';
  static String get updateSpareTime => _updateSpareTime;

  static const _fcmToken = '/firebase-token'; // 사용자 fcm 토큰 등록
  static String get fcmTokenRegister => _fcmToken;

  // alarm
  static const _alarmSettings = '/users/me/alarm-settings';
  static const _currentDevice = '/users/me/devices/current';
  static const _alarmWindow = '$_schedules/alarm-window';
  static const _alarmStatus = '/users/me/alarm-status';

  static String get alarmSettings => _alarmSettings;
  static String get currentDevice => _currentDevice;
  static String get alarmWindow => _alarmWindow;
  static String get alarmStatus => _alarmStatus;
}
