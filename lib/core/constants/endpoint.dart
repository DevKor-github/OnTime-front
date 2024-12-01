import 'dart:core';

class Endpoint {
  static const _createSchedule = '/schedule/add';
  static const _getSchedule = '/schedule/show';
  static const _getSchedulesByDate = '/schedule/show';
  static const _updateSchedule = '/schedule/update';
  static const _deleteSchedule = '/schedule/delete';

  static get createSchedule => _createSchedule;
  static getSchedule(String scheduleId) => '$_getSchedule$scheduleId';
  static get getSchedulesByDate => _getSchedulesByDate;
  static updateSchedule(String scheduleId) => '$_updateSchedule$scheduleId';
  static deleteSchedule(String scheduleId) => '$_deleteSchedule$scheduleId';
}
