import 'package:equatable/equatable.dart';

class CivilTimeOccurrence extends Equatable {
  const CivilTimeOccurrence({
    required this.offsetSeconds,
    required this.instantUtc,
  });

  final int offsetSeconds;
  final DateTime instantUtc;

  @override
  List<Object> get props => [offsetSeconds, instantUtc];
}
