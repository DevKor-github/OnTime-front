import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:on_time_front/presentation/onboarding/preparation_reordarable_list.dart';

@widgetbook.UseCase(name: 'Default', type: PreparationReorderableList)
Widget buildTileUseCase(BuildContext context) {
  return const Scaffold(body: PreparationReorderableList());
}
