import 'package:go_router/go_router.dart';

Map<String, dynamic>? routeExtraMap(Object? extra) {
  if (extra == null) return null;
  if (extra is Map<String, dynamic>) return extra;
  if (extra is! Map) return null;

  final parsed = <String, dynamic>{};
  for (final entry in extra.entries) {
    final key = entry.key;
    if (key is! String) return null;
    parsed[key] = entry.value;
  }
  return parsed;
}

String? routeStringValue(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

bool? routeBoolValue(Object? value) {
  if (value is bool) return value;
  if (value is int) {
    if (value == 1) return true;
    if (value == 0) return false;
  }
  if (value is String) {
    switch (value.toLowerCase()) {
      case 'true':
      case '1':
        return true;
      case 'false':
      case '0':
        return false;
    }
  }
  return null;
}

DateTime? calendarInitialDateFromState(GoRouterState state) {
  return parseCalendarInitialDate(
    extra: state.extra,
    queryParameters: state.uri.queryParameters,
  );
}

DateTime? parseCalendarInitialDate({
  Object? extra,
  Map<String, String> queryParameters = const {},
}) {
  final extraDate = _dateTimeValue(extra);
  if (extraDate != null) return extraDate;

  return _dateTimeValue(
    queryParameters['date'] ?? queryParameters['initialDate'],
  );
}

String calendarRouteLocation(DateTime date) {
  final normalizedDate = DateTime(date.year, date.month, date.day);
  return Uri(
    path: '/calendar',
    queryParameters: {'date': normalizedDate.toIso8601String()},
  ).toString();
}

Map<String, dynamic>? scheduleStartRouteExtraFromState(GoRouterState state) {
  final extra = routeExtraMap(state.extra);
  final queryExtra = _scheduleStartExtraFromQuery(state.uri.queryParameters);
  if (queryExtra == null) return extra;
  return {
    ...queryExtra,
    if (extra != null) ...extra,
  };
}

class EarlyLateRouteArguments {
  const EarlyLateRouteArguments({
    required this.earlyLateTime,
    required this.isLate,
  });

  final int earlyLateTime;
  final bool isLate;
}

EarlyLateRouteArguments? earlyLateRouteArgumentsFromState(
  GoRouterState state,
) {
  return parseEarlyLateRouteArguments(
    extra: state.extra,
    queryParameters: state.uri.queryParameters,
  );
}

EarlyLateRouteArguments? parseEarlyLateRouteArguments({
  Object? extra,
  Map<String, String> queryParameters = const {},
}) {
  final extraMap = routeExtraMap(extra);
  final earlyLateTime = _intValue(extraMap?['earlyLateTime']) ??
      _intValue(queryParameters['earlyLateTime']);
  final isLate = routeBoolValue(extraMap?['isLate']) ??
      routeBoolValue(queryParameters['isLate']);

  if (earlyLateTime == null || isLate == null) return null;
  return EarlyLateRouteArguments(
    earlyLateTime: earlyLateTime,
    isLate: isLate,
  );
}

String earlyLateRouteLocation({
  required int earlyLateTime,
  required bool isLate,
}) {
  return Uri(
    path: '/earlyLate',
    queryParameters: {
      'earlyLateTime': earlyLateTime.toString(),
      'isLate': isLate.toString(),
    },
  ).toString();
}

Map<String, dynamic>? _scheduleStartExtraFromQuery(
  Map<String, String> queryParameters,
) {
  final parsed = <String, dynamic>{};

  for (final key in const [
    'scheduleId',
    'scheduleFingerprint',
    'promptVariant',
    'alarmLaunchAction',
  ]) {
    final value = routeStringValue(queryParameters[key]);
    if (value != null) parsed[key] = value;
  }

  final isFiveMinutesBefore = routeBoolValue(
    queryParameters['isFiveMinutesBefore'],
  );
  if (isFiveMinutesBefore != null) {
    parsed['isFiveMinutesBefore'] = isFiveMinutesBefore;
  }

  return parsed.isEmpty ? null : parsed;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
