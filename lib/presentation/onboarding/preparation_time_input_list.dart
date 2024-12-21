import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/mutly_page_form.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_page_view_layout.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_screen.dart';
import 'package:on_time_front/shared/components/tile.dart';
import 'package:on_time_front/shared/theme/tile_style.dart';

class PreparationTimeInputFieldList extends StatefulWidget {
  const PreparationTimeInputFieldList(
      {super.key,
      required this.formKey,
      required this.initalValue,
      this.onSaved});

  final GlobalKey<FormState> formKey;
  final PreparationFormData initalValue;
  final Function(List<Duration>)? onSaved;

  @override
  State<PreparationTimeInputFieldList> createState() =>
      _PreparationTimeInputFieldListState();
}

class _PreparationTimeInputFieldListState
    extends State<PreparationTimeInputFieldList> {
  List<Duration> preparationTimeList = [];

  @override
  void initState() {
    preparationTimeList = widget.initalValue.preparationStepList
        .map((e) => e.preparationTime)
        .toList();
    super.initState();
  }

  void _showModalBottomSheet(
      BuildContext context, FormFieldState<Duration> field) {
    showModalBottomSheet<void>(
      isDismissible: false,
      context: context,
      builder: (BuildContext context) {
        final textTheme = Theme.of(context).textTheme;
        int minutes = field.value!.inMinutes;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 29.0, vertical: 28.0),
          child: SizedBox(
            height: 334,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('시간을 선택해주세요', style: textTheme.titleMedium),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 69.0,
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                            initialItem: field.value!.inMinutes),
                        looping: true,
                        itemExtent: 32,
                        onSelectedItemChanged: (int value) {
                          minutes = value;
                        },
                        children: List.generate(
                            60,
                            (index) => Text(
                                (index < 10 ? '0' : '') + index.toString())),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(
                                Color.fromARGB(255, 220, 227, 255)),
                            foregroundColor: WidgetStatePropertyAll(
                                Color.fromARGB(255, 92, 121, 251)),
                          ),
                          child: Text('취소')),
                    ),
                    SizedBox(width: 20.0),
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                        onPressed: () {
                          field.didChange(Duration(minutes: minutes));
                          Navigator.pop(context);
                        },
                        child: Text('확인'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OnboardingPageViewLayout(
      title: Text(
        '과정별로 소요되는 시간을\n알려주세요',
        style: textTheme.titleLarge,
      ),
      form: MultiPageFormField(
        key: widget.formKey,
        onSaved: () {
          widget.onSaved?.call(preparationTimeList);
        },
        child: ListView.builder(
          itemCount: preparationTimeList.length,
          itemBuilder: (context, index) {
            return FormField<Duration>(
              onSaved: (value) {
                preparationTimeList[index] = value!;
              },
              initialValue: preparationTimeList[index],
              builder: (field) => Tile(
                style: TileStyle(
                    margin: EdgeInsets.only(bottom: 8),
                    backgroundColor: Color(0xFFE6E9F9)),
                trailing: Row(
                  children: [
                    GestureDetector(
                      child: Text((field.value!.inMinutes < 10 ? '0' : '') +
                          field.value!.inMinutes.toString()),
                      onTap: () {
                        _showModalBottomSheet(context, field);
                      },
                    ),
                    SizedBox(width: 35),
                    Text('분'),
                  ],
                ),
                child: Text(widget
                    .initalValue.preparationStepList[index].preparationName),
              ),
            );
          },
        ),
      ),
    );
  }
}
