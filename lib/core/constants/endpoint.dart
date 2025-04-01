import 'dart:core';

class Endpoint {
  //user
  static const _signIn = '/login';
  static const _signUp = '/sign-up';
  static const _signInWithGoogle = '/oauth2/google/login';
  static const _getUser = '/users/me';

  static get signIn => _signIn;
  static get signUp => _signUp;
  static get signInWithGoogle => _signInWithGoogle;
  static get getUser => _getUser;

  // schedule
  static const _schedules = '/schedules';

  static getScheduleById(String scheduleId) => '$_schedules/$scheduleId';
  static get getSchedulesByDate => _schedules;

  static get createSchedule => _schedules;
  static updateSchedule(String scheduleId) => '$_schedules/$scheduleId';
  static deleteScheduleById(String scheduleId) => '$_schedules/$scheduleId';

  // preparation
  static const _createDefaultPreparation =
      '$_getUser/onboarding'; // 사용자 준비과정 첫 세팅

  static const _defaultPreparation = '/users/preparations'; // 사용자 기본 준비과정 조회

  static get createDefaultPreparation => _createDefaultPreparation;

  static _prepartionByScheduleId(String scheduleId) =>
      '$_schedules/$scheduleId/preparations';

  static getCreateCustomPreparation(String scheduleId) =>
      _prepartionByScheduleId(scheduleId);

  static getPreparationByScheduleId(String scheduleId) =>
      _prepartionByScheduleId(scheduleId);

  static updatePreparationByScheduleId(String scheduleId) =>
      _prepartionByScheduleId(scheduleId);

  static get getDefaultPreparation => _defaultPreparation;

  static get updateDefaultPreparation => _defaultPreparation;
}
