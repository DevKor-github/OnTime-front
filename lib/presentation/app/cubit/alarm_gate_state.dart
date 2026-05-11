part of 'alarm_gate_cubit.dart';

enum AlarmGateStatus { initial, allowed, required, dismissed, unsupported }

class AlarmGateState extends Equatable {
  const AlarmGateState._({required this.status});

  const AlarmGateState.initial() : this._(status: AlarmGateStatus.initial);

  const AlarmGateState.allowed() : this._(status: AlarmGateStatus.allowed);

  const AlarmGateState.required() : this._(status: AlarmGateStatus.required);

  const AlarmGateState.dismissed() : this._(status: AlarmGateStatus.dismissed);

  const AlarmGateState.unsupported()
    : this._(status: AlarmGateStatus.unsupported);

  final AlarmGateStatus status;

  bool get isResolved => status != AlarmGateStatus.initial;

  bool get shouldPrompt => status == AlarmGateStatus.required;

  @override
  List<Object> get props => [status];
}
