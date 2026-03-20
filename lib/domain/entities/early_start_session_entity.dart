import 'package:equatable/equatable.dart';

class EarlyStartSessionEntity extends Equatable {
  const EarlyStartSessionEntity({
    required this.scheduleId,
    required this.startedAt,
  });

  final String scheduleId;
  final DateTime startedAt;

  @override
  List<Object?> get props => [scheduleId, startedAt];
}
