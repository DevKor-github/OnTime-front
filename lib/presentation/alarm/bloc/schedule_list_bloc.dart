// // schedule_list_bloc.dart
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:dio/dio.dart';
// import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';
// import 'package:on_time_front/domain/entities/schedule_entity.dart';

// class ScheduleListBloc extends Bloc<ScheduleListEvent, ScheduleListState> {
//   final ScheduleRemoteDataSourceImpl scheduleRemoteDataSource;

//   ScheduleListBloc(this.scheduleRemoteDataSource)
//       : super(ScheduleListInitial());

//   @override
//   Stream<ScheduleListState> mapEventToState(ScheduleListEvent event) async* {
//     if (event is LoadSchedules) {
//       yield ScheduleListLoading();
//       try {
//         final schedules = await scheduleRemoteDataSource.getSchedulesByDate(
//           DateTime(2024, 02, 01, 00, 00),
//           null,
//         );
//         yield ScheduleListLoaded(schedules);
//       } catch (e) {
//         yield ScheduleListError(e.toString());
//       }
//     }
//   }
// }
