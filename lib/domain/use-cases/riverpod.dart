import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_time_front/data/repositories/riverpod.dart';
import 'package:on_time_front/domain/use-cases/create_schedule_with_place_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'riverpod.g.dart';

@riverpod
CreateScheduleWithPlaceUseCase createScheduleWithPlaceUseCase(Ref ref) {
  final scheduleRepository = ref.read(scheduleRepositoryProvider);
  return CreateScheduleWithPlaceUseCase(scheduleRepository);
}
