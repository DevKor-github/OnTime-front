import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/mutly_page_form.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_page_view_layout.dart';
import 'package:on_time_front/shared/components/time_stepper.dart';

class ScheduleSpareTimeField extends StatefulWidget {
  const ScheduleSpareTimeField(
      {super.key,
      required this.formKey,
      required this.initialValue,
      this.onSaved});

  final GlobalKey<FormState> formKey;
  final Duration initialValue;
  final Function(Duration)? onSaved;

  @override
  State<ScheduleSpareTimeField> createState() => _ScheduleSpareTimeFieldState();
}

class _ScheduleSpareTimeFieldState extends State<ScheduleSpareTimeField> {
  late Duration spareTime;

  @override
  void initState() {
    spareTime = widget.initialValue;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OnboardingPageViewLayout(
      title: Text(
        '얼마만큼의 여유시간을 남기고\n약속 장소에 도착할지 알려주세요',
        style: textTheme.titleLarge,
      ),
      form: MultiPageFormField(
        key: widget.formKey,
        onSaved: () {
          widget.onSaved?.call(spareTime);
        },
        child: Padding(
          padding: EdgeInsets.only(top: 90.0),
          child: Column(
            children: [
              FormField<Duration>(
                  initialValue: widget.initialValue,
                  onSaved: (value) {
                    setState(() {
                      spareTime = value!;
                    });
                  },
                  builder: (field) => TimeStepper(
                        step: 5,
                        onChanged: (value) {
                          field.didChange(Duration(minutes: value));
                        },
                        value: field.value!.inMinutes,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 35.0),
                          child: Text(
                            '${field.value!.inMinutes}분',
                            style: textTheme.titleSmall,
                          ),
                        ),
                      )),
              Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}
