part of 'early_late_screen_bloc.dart';

sealed class EarlyLateScreenState extends Equatable {
  const EarlyLateScreenState();

  @override
  List<Object> get props => [];
}

class EarlyLateScreenInitial extends EarlyLateScreenState {}

class EarlyLateScreenLoadSuccess extends EarlyLateScreenState {
  final List<bool> checklist;
  final bool isLate;
  final String earlylateMessage;
  final String earlylateImage;

  const EarlyLateScreenLoadSuccess({
    required this.checklist,
    required this.isLate,
    required this.earlylateMessage,
    required this.earlylateImage,
  });

  @override
  List<Object> get props => [
        checklist,
        isLate,
        earlylateMessage,
        earlylateImage,
      ];
}
