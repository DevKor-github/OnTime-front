import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';

class TimedPreparationSnapshotEntity extends Equatable {
  const TimedPreparationSnapshotEntity({
    required this.preparation,
    required this.savedAt,
    required this.scheduleFingerprint,
  });

  final PreparationWithTimeEntity preparation;
  final DateTime savedAt;
  final String scheduleFingerprint;

  TimedPreparationSnapshotEntity copyWith({
    PreparationWithTimeEntity? preparation,
    DateTime? savedAt,
    String? scheduleFingerprint,
  }) {
    return TimedPreparationSnapshotEntity(
      preparation: preparation ?? this.preparation,
      savedAt: savedAt ?? this.savedAt,
      scheduleFingerprint: scheduleFingerprint ?? this.scheduleFingerprint,
    );
  }

  @override
  List<Object?> get props => [preparation, savedAt, scheduleFingerprint];
}
