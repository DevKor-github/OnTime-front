part of 'notification_gate_cubit.dart';

enum NotificationGateStatus {
  initial,
  allowed,
  required,
  dismissed,
}

class NotificationGateState extends Equatable {
  const NotificationGateState._({
    required this.status,
  });

  const NotificationGateState.initial()
      : this._(status: NotificationGateStatus.initial);

  const NotificationGateState.allowed()
      : this._(status: NotificationGateStatus.allowed);

  const NotificationGateState.required()
      : this._(status: NotificationGateStatus.required);

  const NotificationGateState.dismissed()
      : this._(status: NotificationGateStatus.dismissed);

  final NotificationGateStatus status;

  bool get isResolved => status != NotificationGateStatus.initial;

  bool get shouldPrompt => status == NotificationGateStatus.required;

  @override
  List<Object> get props => [status];
}
