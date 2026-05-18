import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/models/ordered_preparation_step_model.dart';
import 'package:on_time_front/data/models/preparation_template_model.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

void main() {
  test('ordered preparation steps serialize zero-based orderIndex', () {
    final preparation = PreparationEntity(
      preparationStepList: [
        const PreparationStepEntity(
          id: 'prep-1',
          preparationName: 'Pack laptop',
          preparationTime: Duration(minutes: 5),
          nextPreparationId: 'prep-2',
        ),
        const PreparationStepEntity(
          id: 'prep-2',
          preparationName: 'Shower',
          preparationTime: Duration(minutes: 15),
        ),
      ],
    );

    final json = OrderedPreparationStepModel.fromPreparationEntity(
      preparation,
    ).map((step) => step.toJson()).toList();

    expect(json, [
      {
        'preparationId': 'prep-1',
        'preparationName': 'Pack laptop',
        'preparationTime': 5,
        'orderIndex': 0,
      },
      {
        'preparationId': 'prep-2',
        'preparationName': 'Shower',
        'preparationTime': 15,
        'orderIndex': 1,
      },
    ]);
  });

  test(
    'template response maps ordered steps back to linked preparation entity',
    () {
      final entity = PreparationTemplateModel.fromJson({
        'templateId': 'template-1',
        'templateName': 'Work',
        'createdAt': '2026-05-14T02:10:00Z',
        'updatedAt': '2026-05-14T02:11:00Z',
        'deletedAt': null,
        'preparations': [
          {
            'preparationId': 'prep-2',
            'preparationName': 'Shower',
            'preparationTime': 15,
            'orderIndex': 1,
          },
          {
            'preparationId': 'prep-1',
            'preparationName': 'Pack laptop',
            'preparationTime': 5,
            'orderIndex': 0,
          },
        ],
      }).toEntity();

      expect(entity.id, 'template-1');
      expect(entity.name, 'Work');
      expect(entity.isDeleted, isFalse);
      expect(entity.preparation.preparationStepList.first.id, 'prep-1');
      expect(
        entity.preparation.preparationStepList.first.nextPreparationId,
        'prep-2',
      );
      expect(
        entity.preparation.preparationStepList.last.nextPreparationId,
        isNull,
      );
    },
  );

  test('template upsert request serializes full replacement payload', () {
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
    );

    expect(request.toJson(), {
      'templateId': 'template-1',
      'templateName': 'Work',
      'preparations': [
        {
          'preparationId': 'prep-1',
          'preparationName': 'Pack laptop',
          'preparationTime': 5,
          'orderIndex': 0,
        },
      ],
    });
  });
}
