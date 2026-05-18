import 'package:json_annotation/json_annotation.dart';

enum SchedulePreparationMode {
  @JsonValue('DEFAULT')
  defaultPreparation,
  @JsonValue('TEMPLATE')
  template,
  @JsonValue('CUSTOM')
  custom,
}
