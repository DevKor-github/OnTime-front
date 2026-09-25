part of 'default_preparation_spare_time_form_bloc.dart';

enum DefaultPreparationSpareTimeStatus {
  initial,
  loading,
  success,
  submitting,
  submitted,
  followUpPending,
  error,
}

class DefaultPreparationSpareTimeFormState extends Equatable {
  const DefaultPreparationSpareTimeFormState({
    this.status = DefaultPreparationSpareTimeStatus.initial,
    this.spareTime,
    this.preparation,
    this.baseline,
    this.failure,
    this.receipt,
    this.editorVersion = 0,
  });
  final DefaultPreparationSpareTimeStatus status;
  final Duration? spareTime;
  final PreparationEntity? preparation;
  final DefaultPreferencesSnapshot? baseline;
  final DefaultPreferencesFailure? failure;
  final DefaultPreferencesSaveReceipt? receipt;
  final int editorVersion;
  bool get hasEditableData => spareTime != null && preparation != null;
  bool get canEdit =>
      hasEditableData &&
      receipt == null &&
      (status == DefaultPreparationSpareTimeStatus.success ||
          status == DefaultPreparationSpareTimeStatus.error);
  bool get needsReload =>
      failure == DefaultPreferencesFailure.conflict ||
      failure == DefaultPreferencesFailure.unavailable;
  bool get canSubmit => canEdit && baseline != null && !needsReload;

  @override
  List<Object?> get props => [
    status,
    spareTime,
    preparation,
    baseline,
    failure,
    receipt,
    editorVersion,
  ];

  DefaultPreparationSpareTimeFormState copyWith({
    DefaultPreparationSpareTimeStatus? status,
    Duration? spareTime,
    PreparationEntity? preparation,
    DefaultPreferencesFailure? failure,
    bool clearFailure = false,
    DefaultPreferencesSaveReceipt? receipt,
  }) => DefaultPreparationSpareTimeFormState(
    status: status ?? this.status,
    spareTime: spareTime ?? this.spareTime,
    preparation: preparation ?? this.preparation,
    baseline: baseline,
    failure: clearFailure ? null : failure ?? this.failure,
    receipt: receipt ?? this.receipt,
    editorVersion: editorVersion,
  );
}
