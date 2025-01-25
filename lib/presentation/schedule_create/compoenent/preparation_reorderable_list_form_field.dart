import 'package:flutter/material.dart';

class PreparationReorderableListFormField extends FormField<List<int>> {
  PreparationReorderableListFormField(
      {super.key,
      super.onSaved,
      super.initialValue,
      required this.itemCount,
      required this.itemBuilder})
      : super(
          builder: (FormFieldState<List<int>> field) {
            Widget proxyDecorator(
                Widget child, int index, Animation<double> animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (BuildContext context, Widget? child) {
                  return SizedBox(
                    child: child,
                  );
                },
                child: child,
              );
            }

            return ReorderableListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              proxyDecorator: proxyDecorator,
              itemCount: itemCount,
              itemBuilder: (context, index) =>
                  itemBuilder(context, field.value![index]),
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = field.value!.removeAt(oldIndex);
                field.value!.insert(newIndex, item);
                field.didChange(field.value!);
              },
            );
          },
        );
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  FormFieldState<List<int>> createState() =>
      PreparationReorderableListFormFieldState();
}

class PreparationReorderableListFormFieldState
    extends FormFieldState<List<int>> {
  void elementAdded() {
    value!.add(value!.length);
    didChange(value);
  }
}
