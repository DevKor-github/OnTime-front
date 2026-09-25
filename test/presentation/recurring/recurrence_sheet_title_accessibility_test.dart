import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';

void main() {
  for (final entry in const {
    'ko': '겹치는 일정 확인',
    'en': 'Conflicting occurrences',
  }.entries) {
    testWidgets(
      '${entry.key} recurrence title paints its full height at320px text2.5',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(entry.key),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.5)),
              child: child!,
            ),
            home: Scaffold(
              body: RecurrenceSheet(
                title: entry.value,
                onBack: () {},
                children: const [Text('Synthetic review body')],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = find.text(entry.value);
        final element = tester.element(title);
        final text = tester.widget<Text>(title);
        final painter = TextPainter(
          text: TextSpan(
            text: entry.value,
            style: DefaultTextStyle.of(element).style.merge(text.style),
          ),
          textDirection: Directionality.of(element),
          textScaler: MediaQuery.textScalerOf(element),
          locale: Localizations.localeOf(element),
        )..layout(maxWidth: tester.getSize(title).width);
        final needed = painter.height;
        painter.dispose();
        expect(
          tester.getSize(title).height,
          greaterThanOrEqualTo(needed - 0.1),
          reason:
              'A clipped title can silently hide lines without a RenderFlex exception.',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
