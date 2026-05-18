import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';
import 'package:on_time_front/data/models/create_defualt_preparation_request_model.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

void main() {
  late _PreparationAdapter adapter;
  late PreparationRemoteDataSourceImpl dataSource;

  setUp(() {
    adapter = _PreparationAdapter();
    final dio = Dio(
      BaseOptions(baseUrl: 'https://example.com', validateStatus: (_) => true),
    )..httpClientAdapter = adapter;
    dataSource = PreparationRemoteDataSourceImpl(dio);
  });

  test(
    'create and update calls serialize preparation steps for backend',
    () async {
      final preparation = _preparation();

      await dataSource.createCustomPreparation(preparation, 'schedule-1');
      await dataSource.updatePreparationByScheduleId(preparation, 'schedule-1');
      await dataSource.updateDefaultPreparation(preparation);

      expect(adapter.requests.map((request) => request.method), [
        'POST',
        'PUT',
        'PUT',
      ]);
      expect(adapter.requests[0].body, isA<List<dynamic>>());
      expect(
        (adapter.requests[0].body as List).first['preparationName'],
        'Shower',
      );
      expect(
        (adapter.requests[1].body as List).first['preparationId'],
        'step-1',
      );
      expect(
        (adapter.requests[2].body as List).first['preparationId'],
        'step-1',
      );
    },
  );

  test(
    'default create and spare time update send their request bodies',
    () async {
      await dataSource.createDefaultPreparation(
        CreateDefaultPreparationRequestModel.fromEntity(
          preparationEntity: _preparation(),
          spareTime: const Duration(minutes: 5),
          note: 'note',
        ),
      );
      await dataSource.updateSpareTime(const Duration(minutes: 15));

      expect(adapter.requests.first.method, 'PUT');
      expect(
        (adapter.requests.first.body
            as Map<String, dynamic>)['preparationList'],
        isA<List>(),
      );
      expect(
        (adapter.requests.last.body as Map<String, dynamic>)['newSpareTime'],
        15,
      );
    },
  );

  test(
    'get preparation calls map ordered backend steps into entities',
    () async {
      final bySchedule = await dataSource.getPreparationByScheduleId(
        'schedule-1',
      );
      final defaultPreparation = await dataSource.getDefualtPreparation();

      expect(bySchedule.preparationStepList.map((step) => step.id), [
        'step-1',
        'step-2',
      ]);
      expect(defaultPreparation.preparationStepList.map((step) => step.id), [
        'step-1',
        'step-2',
      ]);
      expect(bySchedule.totalDuration, const Duration(minutes: 15));
    },
  );

  test('non-200 responses surface failures', () async {
    adapter.statusCode = 500;

    await expectLater(
      dataSource.createCustomPreparation(_preparation(), 'schedule-1'),
      throwsException,
    );
    await expectLater(dataSource.getDefualtPreparation(), throwsException);
  });
}

PreparationEntity _preparation() {
  return const PreparationEntity(
    preparationStepList: [
      PreparationStepEntity(
        id: 'step-1',
        preparationName: 'Shower',
        preparationTime: Duration(minutes: 10),
        nextPreparationId: 'step-2',
      ),
      PreparationStepEntity(
        id: 'step-2',
        preparationName: 'Pack',
        preparationTime: Duration(minutes: 5),
      ),
    ],
  );
}

class _PreparationRequest {
  const _PreparationRequest({
    required this.method,
    required this.path,
    required this.body,
  });

  final String method;
  final String path;
  final Object? body;
}

class _PreparationAdapter implements HttpClientAdapter {
  int statusCode = 200;
  final requests = <_PreparationRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      _PreparationRequest(
        method: options.method,
        path: options.path,
        body: options.data,
      ),
    );

    if (options.method == 'GET') {
      return _json({
        'data': [
          {
            'preparationId': 'step-1',
            'preparationName': 'Shower',
            'preparationTime': 10,
            'nextPreparationId': 'step-2',
          },
          {
            'preparationId': 'step-2',
            'preparationName': 'Pack',
            'preparationTime': 5,
            'nextPreparationId': null,
          },
        ],
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

  @override
  void close({bool force = false}) {}
}
