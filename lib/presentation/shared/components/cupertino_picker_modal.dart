import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

extension ModalBottomSheetExtension on BuildContext {
  void showCupertinoTimerPickerModal({
    required String title,
    required Duration initialValue,
    required CupertinoTimerPickerMode mode,
    required Function(Duration value) onSaved,
    Function? onDisposed,
  }) {
    showModalBottomSheet<void>(
      isDismissible: false,
      context: this,
      builder: (BuildContext context) {
        final textTheme = Theme.of(context).textTheme;
        Duration duration = initialValue;
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 29.0, vertical: 28.0),
            child: SizedBox(
              height: 334,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  Expanded(
                    child: Center(
                      child: CupertinoTimerPicker(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        mode: mode,
                        initialTimerDuration: initialValue,
                        itemExtent: 32,
                        onTimerDurationChanged: (value) => duration = value,
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
                              //calling order matters
                              Navigator.pop(context);
                              onDisposed?.call();
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
                            Navigator.pop(context);
                            onSaved(duration);
                            onDisposed?.call();
                          },
                          child: Text('확인'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void showCupertinoMinutePickerModal({
    required String title,
    required Duration initialValue,
    required Function(Duration value) onSaved,
    Function? onDisposed,
  }) {
    showModalBottomSheet<void>(
      isDismissible: false,
      context: this,
      builder: (BuildContext context) {
        final textTheme = Theme.of(context).textTheme;
        int minutes = initialValue.inMinutes;
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 29.0, vertical: 28.0),
            child: SizedBox(
              height: 334,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 69.0,
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                              initialItem: initialValue.inMinutes),
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
                              //calling order matters
                              Navigator.pop(context);
                              onDisposed?.call();
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
                            Navigator.pop(context);
                            onSaved(Duration(minutes: minutes));
                            onDisposed?.call();
                          },
                          child: Text('확인'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void showCupertinoDatePickerModal({
    required String title,
    required DateTime initialValue,
    required Function(DateTime value) onSaved,
    required CupertinoDatePickerMode mode,
    Function? onDisposed,
  }) {
    showModalBottomSheet<void>(
      isDismissible: false,
      context: this,
      builder: (BuildContext context) {
        final textTheme = Theme.of(context).textTheme;
        DateTime dateTime = initialValue;
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 29.0, vertical: 28.0),
            child: SizedBox(
              height: 334,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  Expanded(
                    child: Center(
                      child: CupertinoDatePicker(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        mode: mode,
                        initialDateTime: initialValue,
                        itemExtent: 32,
                        onDateTimeChanged: (DateTime value) {
                          dateTime = value;
                        },
                        dateOrder: DatePickerDateOrder.ymd,
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
                              //calling order matters
                              Navigator.pop(context);
                              onDisposed?.call();
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
                            Navigator.pop(context);
                            onSaved(dateTime);
                            onDisposed?.call();
                          },
                          child: Text('확인'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
