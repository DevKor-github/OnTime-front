import 'package:on_time_front/domain/entities/alarm_entities.dart';

class AlarmSettingsModel {
  final bool alarmsEnabled;
  final int defaultAlarmOffsetMinutes;
  final DateTime? updatedAt;

  const AlarmSettingsModel({
    required this.alarmsEnabled,
    required this.defaultAlarmOffsetMinutes,
    this.updatedAt,
  });

  factory AlarmSettingsModel.fromJson(Map<String, dynamic> json) {
    return AlarmSettingsModel(
      alarmsEnabled: json['alarmsEnabled'] as bool? ?? true,
      defaultAlarmOffsetMinutes:
          (json['defaultAlarmOffsetMinutes'] as num?)?.toInt() ?? 5,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alarmsEnabled': alarmsEnabled,
      'defaultAlarmOffsetMinutes': defaultAlarmOffsetMinutes,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  AlarmSettings toEntity() {
    return AlarmSettings(
      alarmsEnabled: alarmsEnabled,
      defaultAlarmOffsetMinutes: defaultAlarmOffsetMinutes,
      updatedAt: updatedAt,
    );
  }

  factory AlarmSettingsModel.fromEntity(AlarmSettings entity) {
    return AlarmSettingsModel(
      alarmsEnabled: entity.alarmsEnabled,
      defaultAlarmOffsetMinutes: entity.defaultAlarmOffsetMinutes,
      updatedAt: entity.updatedAt,
    );
  }
}

class UpdateAlarmSettingsRequestModel {
  final bool alarmsEnabled;

  const UpdateAlarmSettingsRequestModel({required this.alarmsEnabled});

  Map<String, dynamic> toJson() {
    return {
      'alarmsEnabled': alarmsEnabled,
    };
  }
}
