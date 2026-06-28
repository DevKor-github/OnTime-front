import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/schedule_remote_data_source.dart';
import 'package:on_time_front/data/models/create_schedule_request_model.dart';
import 'package:on_time_front/data/models/update_schedule_request_model.dart';

void main() {
  late _ScheduleAdapter adapter;
  late ScheduleRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _ScheduleAdapter();
    final dio = Dio(
      BaseOptions(baseUrl: 'https://example.com', validateStatus: (_) => true),
    )..httpClientAdapter = adapter;
    dataSource = ScheduleRemoteDataSourceImpl(dio);
  });

  test(
    'create, update, delete, start, and finish send schedule API contracts',
    () async {
      final createRequest = _createRequest('schedule-1');
      final updateRequest = _updateRequest('schedule-1');

      await dataSource.createSchedule(createRequest);
      await dataSource.updateSchedule(updateRequest);
      await dataSource.deleteSchedule('schedule-1');
      await dataSource.startSchedule('schedule-1');
      await dataSource.finishSchedule('schedule-1', 7);

      expect(adapter.requests.map((request) => request.method), [
        'POST',
        'PUT',
        'DELETE',
        'POST',
        'PUT',
      ]);
      expect(adapter.requests[0].body['scheduleName'], 'Meeting schedule-1');
      expect(adapter.requests[1].body['scheduleName'], 'Meeting schedule-1');
      expect(adapter.requests[3].path, '/schedules/schedule-1/start');
      expect(adapter.requests[4].body, {
        'scheduleId': 'schedule-1',
        'latenessTime': 7,
      });
    },
  );

  test('getScheduleById returns the backend response model', () async {
    final schedule = await dataSource.getScheduleById('schedule-1');

    expect(schedule.scheduleId, 'schedule-1');
    expect(schedule.place.placeId, 'place-1');
    expect(schedule.place.placeName, 'Office');
    expect(schedule.scheduleName, 'Morning meeting');
    expect(schedule.moveTime, 20);
    expect(schedule.scheduleSpareTime, 5);
    expect(schedule.doneStatus, 'NORMAL');
  });

  test(
    'getSchedulesByDate passes date query parameters and maps list response',
    () async {
      final start = DateTime(2026, 5, 15);
      final end = DateTime(2026, 5, 16);

      final schedules = await dataSource.getSchedulesByDate(start, end);

      expect(schedules.map((schedule) => schedule.scheduleId), [
        'schedule-1',
        'schedule-2',
      ]);
      expect(
        adapter.requests.single.query['startDate'],
        start.toIso8601String(),
      );
      expect(adapter.requests.single.query['endDate'], end.toIso8601String());
    },
  );

  test('non-200 responses surface failures for callers', () async {
    adapter.statusCode = 500;

    await expectLater(
      dataSource.createSchedule(_createRequest('schedule-1')),
      throwsException,
    );
    await expectLater(
      dataSource.getScheduleById('schedule-1'),
      throwsException,
    );
  });
}

CreateScheduleRequestModel _createRequest(String id) {
  return CreateScheduleRequestModel(
    scheduleId: id,
    placeId: 'place-1',
    placeName: 'Office',
    scheduleName: 'Meeting $id',
    scheduleTime: DateTime(2026, 5, 15, 9),
    moveTime: 20,
    isChange: false,
    isStarted: false,
    scheduleSpareTime: 5,
    scheduleNote: 'note',
  );
}

UpdateScheduleRequestModel _updateRequest(String id) {
  return UpdateScheduleRequestModel(
    scheduleId: id,
    placeId: 'place-1',
    placeName: 'Office',
    scheduleName: 'Meeting $id',
    scheduleTime: DateTime(2026, 5, 15, 9),
    moveTime: 20,
    scheduleSpareTime: 5,
    scheduleNote: 'note',
  );
}

class _ScheduleRequest {
  const _ScheduleRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Map<String, dynamic> body;
}

class _ScheduleAdapter implements HttpClientAdapter {
  int statusCode = 200;
  final requests = <_ScheduleRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      _ScheduleRequest(
        method: options.method,
        path: options.path,
        query: Map<String, dynamic>.from(options.queryParameters),
        body: options.data is Map
            ? Map<String, dynamic>.from(options.data as Map)
            : const {},
      ),
    );

    if (options.method == 'GET' && options.path.contains('schedule-1')) {
      return _json({'data': _scheduleJson('schedule-1')});
    }
    if (options.method == 'GET') {
      return _json({
        'data': [_scheduleJson('schedule-1'), _scheduleJson('schedule-2')],
      });
    }
    return _json({'data': null});
  }

  ResponseBody _json(Object body) {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _scheduleJson(String id) {
    return {
      'scheduleId': id,
      'place': {'placeId': 'place-1', 'placeName': 'Office'},
      'scheduleName': id == 'schedule-1' ? 'Morning meeting' : 'Lunch',
      'scheduleTime': DateTime(2026, 5, 15, 9).toIso8601String(),
      'moveTime': 20,
      'scheduleSpareTime': 5,
      'scheduleNote': 'note',
      'latenessTime': 0,
      'doneStatus': 'NORMAL',
    };
  }

  @override
  void close({bool force = false}) {}
}
