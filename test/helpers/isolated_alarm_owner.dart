import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/services/alarm_operation_coordinator.dart';

/// Unit fixtures intentionally use an ephemeral journal; file persistence and
/// restart recovery are exercised separately with actual temporary files.
AlarmOperationCoordinator isolatedAlarmOwner() {
  final gate = LocalDataOperationGate();
  final owner = AlarmOperationCoordinator(gate);
  addTearDown(() {
    owner.dispose();
    gate.dispose();
  });
  return owner;
}
