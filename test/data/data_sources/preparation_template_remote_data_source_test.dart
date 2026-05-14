import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/data/data_sources/preparation_template_remote_data_source.dart';
import 'package:on_time_front/data/models/preparation_template_model.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

import '../../helpers/mock.mocks.dart';

void main() {
  late Dio dio;
  late PreparationTemplateRemoteDataSourceImpl dataSource;

  setUp(() {
    dio = MockAppDio();
    dataSource = PreparationTemplateRemoteDataSourceImpl(dio);
  });

  test('gets active preparation templates', () async {
    when(dio.get(Endpoint.preparationTemplates)).thenAnswer(
      (_) async => Response(
        statusCode: 200,
        requestOptions: RequestOptions(path: Endpoint.preparationTemplates),
        data: {
          'status': 'success',
          'data': [
            {
              'templateId': 'template-1',
              'templateName': 'Work',
              'createdAt': '2026-05-14T02:10:00Z',
              'updatedAt': '2026-05-14T02:10:00Z',
              'deletedAt': null,
              'preparations': [],
            },
          ],
        },
      ),
    );

    final templates = await dataSource.getPreparationTemplates();

    expect(templates.single.id, 'template-1');
    expect(templates.single.name, 'Work');
  });

  test('creates preparation template with ordered steps', () async {
    final request = UpsertPreparationTemplateRequestModel.fromValues(
      templateId: 'template-1',
      templateName: 'Work',
      preparation: const PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'prep-1',
            preparationName: 'Pack laptop',
            preparationTime: Duration(minutes: 5),
          ),
        ],
      ),
    ).toJson();

    when(dio.post(Endpoint.preparationTemplates, data: request)).thenAnswer(
      (_) async => Response(
        statusCode: 200,
        requestOptions: RequestOptions(path: Endpoint.preparationTemplates),
      ),
    );

    await dataSource.createPreparationTemplate(
      templateId: 'template-1',
      templateName: 'Work',
      preparation: const PreparationEntity(
        preparationStepList: [
          PreparationStepEntity(
            id: 'prep-1',
            preparationName: 'Pack laptop',
            preparationTime: Duration(minutes: 5),
          ),
        ],
      ),
    );

    verify(dio.post(Endpoint.preparationTemplates, data: request)).called(1);
  });

  test('deletes preparation template by id', () async {
    when(dio.delete(Endpoint.preparationTemplateById('template-1'))).thenAnswer(
      (_) async => Response(
        statusCode: 200,
        requestOptions: RequestOptions(
          path: Endpoint.preparationTemplateById('template-1'),
        ),
      ),
    );

    await dataSource.deletePreparationTemplate('template-1');

    verify(
      dio.delete(Endpoint.preparationTemplateById('template-1')),
    ).called(1);
  });
}
