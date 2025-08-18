part of 'default_preparation_spare_time_form_bloc.dart';

enum DefaultPreparationSpareTimeStatus {
  initial,
  loading,
  success,
  error,
}

class DefaultPreparationSpareTimeFormState extends Equatable {
  const DefaultPreparationSpareTimeFormState({
    this.status = DefaultPreparationSpareTimeStatus.initial,
    this.spareTime,
    this.preparation,
  });
  final DefaultPreparationSpareTimeStatus status;
  final Duration? spareTime;
  final PreparationEntity? preparation;

  @override
  List<Object?> get props => [status, spareTime, preparation];

  DefaultPreparationSpareTimeFormState copyWith({
    DefaultPreparationSpareTimeStatus? status,
    Duration? spareTime,
    PreparationEntity? preparation,
  }) {
    return DefaultPreparationSpareTimeFormState(
      status: status ?? this.status,
      spareTime: spareTime ?? this.spareTime,
      preparation: preparation ?? this.preparation,
    );
  }
}
