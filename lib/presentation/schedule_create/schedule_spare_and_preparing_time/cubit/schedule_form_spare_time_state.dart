part of 'schedule_form_spare_time_cubit.dart';

class ScheduleFormSpareTimeState extends Equatable {
  const ScheduleFormSpareTimeState({
    this.spareTime = const ScheduleSpareTimeInputModel.pure(),
    this.preparation,
    this.totalPreparationTime = Duration.zero,
    this.overlapDuration,
    this.isOverlapping = false,
  });

  final ScheduleSpareTimeInputModel spareTime;
  final PreparationEntity? preparation;
  final Duration totalPreparationTime;
  final Duration? overlapDuration;
  final bool isOverlapping;

  bool get isValid => Formz.validate([spareTime]) && !isOverlapping;

  /// Returns true if there's an overlap warning or error to display
  bool get hasOverlapMessage => overlapDuration != null;

  /// Returns true if the overlap is an error (already overlapping, minutes <= 0)
  bool get isOverlapError => isOverlapping;

  /// Returns the overlap message based on whether it's an error or warning
  /// Requires BuildContext for localization
  String? getOverlapMessage(BuildContext context) {
    if (overlapDuration == null) return null;

    final localizations = AppLocalizations.of(context)!;
    final minutes = overlapDuration!.inMinutes.abs();
    final scheduleName =
        context.read<ScheduleFormBloc>().state.previousScheduleName ?? '';

    if (isOverlapping) {
      return localizations.previousScheduleOverlapError(minutes, scheduleName);
    } else {
      return localizations.scheduleOverlapWarning(minutes, scheduleName);
    }
  }

  ScheduleFormSpareTimeState copyWith({
    ScheduleSpareTimeInputModel? spareTime,
    PreparationEntity? preparation,
    Duration? totalPreparationTime,
    Duration? overlapDuration,
    bool? isOverlapping,
    bool clearOverlap = false,
  }) {
    return ScheduleFormSpareTimeState(
      spareTime: spareTime ?? this.spareTime,
      preparation: preparation ?? this.preparation,
      totalPreparationTime: totalPreparationTime ?? this.totalPreparationTime,
      overlapDuration:
          clearOverlap ? null : (overlapDuration ?? this.overlapDuration),
      isOverlapping:
          clearOverlap ? false : (isOverlapping ?? this.isOverlapping),
    );
  }

  static ScheduleFormSpareTimeState fromScheduleFormState(
      ScheduleFormState state) {
    return ScheduleFormSpareTimeState(
      spareTime: ScheduleSpareTimeInputModel.pure(
          state.scheduleSpareTime ?? Duration.zero),
      preparation: state.preparation,
      totalPreparationTime: state.totalPreparationTime,
    );
  }

  @override
  List<Object?> get props => [
        spareTime,
        preparation,
        totalPreparationTime,
        overlapDuration ?? const Duration(),
        isOverlapping,
      ];
}
