part of 'default_preparation_spare_time_form_bloc.dart';

enum DefaultPreparationSpareTimeStatus {
  initial,
  loading,
  success,
  submitting,
  submitted,
  error,
}

class DefaultPreparationSpareTimeFormState extends Equatable {
  const DefaultPreparationSpareTimeFormState({
    this.status = DefaultPreparationSpareTimeStatus.initial,
    this.spareTime,
    this.preparation,
    this.errorMessage,
  });
  final DefaultPreparationSpareTimeStatus status;
  final Duration? spareTime;
  final PreparationEntity? preparation;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, spareTime, preparation, errorMessage];

  DefaultPreparationSpareTimeFormState copyWith({
    DefaultPreparationSpareTimeStatus? status,
    Duration? spareTime,
    PreparationEntity? preparation,
    String? errorMessage,
  }) {
    return DefaultPreparationSpareTimeFormState(
      status: status ?? this.status,
      spareTime: spareTime ?? this.spareTime,
      preparation: preparation ?? this.preparation,
      errorMessage: errorMessage,
    );
  }
}
