import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/shared/components/custom_alert_dialog.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  testWidgets('renders title, content, and actions with configured spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: const Scaffold(
          body: CustomAlertDialog(
            title: Text('Delete schedule?'),
            content: Text('This cannot be undone.'),
            actions: [
              TextButton(onPressed: null, child: Text('Cancel')),
              TextButton(onPressed: null, child: Text('Delete')),
            ],
            titleContentSpacing: 12,
            contentActionsSpacing: 24,
            innerPadding: EdgeInsets.all(10),
          ),
        ),
      ),
    );

    expect(find.text('Delete schedule?'), findsOneWidget);
    expect(find.text('This cannot be undone.'), findsOneWidget);
    expect(find.byType(OverflowBar), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports content-only dialog with explicit semantic label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: const Scaffold(
          body: CustomAlertDialog(
            semanticLabel: 'Info dialog',
            content: Text('Saved'),
            contentTextAlign: TextAlign.center,
            actionsAlignment: MainAxisAlignment.center,
          ),
        ),
      ),
    );

    expect(find.text('Saved'), findsOneWidget);
    expect(find.bySemanticsLabel('Info dialog'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('title-only dialog scales padding for large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.5)),
          child: Scaffold(
            body: CustomAlertDialog(
              title: Text('Large title'),
              titleTextAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Large title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS dialog omits default alert route label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData.copyWith(platform: TargetPlatform.iOS),
        home: const Scaffold(
          body: CustomAlertDialog(
            title: Text('Cupertino title'),
            content: Text('No default Android alert label'),
          ),
        ),
      ),
    );

    expect(find.text('Cupertino title'), findsOneWidget);
    expect(find.bySemanticsLabel('Alert'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom theme text styles are applied to title and content', (
    tester,
  ) async {
    const titleStyle = TextStyle(fontSize: 23, color: Colors.red);
    const contentStyle = TextStyle(fontSize: 17, color: Colors.green);

    await tester.pumpWidget(
      MaterialApp(
        theme: themeData.copyWith(
          dialogTheme: const DialogThemeData(
            titleTextStyle: titleStyle,
            contentTextStyle: contentStyle,
          ),
        ),
        home: const Scaffold(
          body: CustomAlertDialog(
            title: Text('Styled title'),
            content: Text('Styled content'),
          ),
        ),
      ),
    );

    final titleDefaultTextStyle = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('Styled title'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    final contentDefaultTextStyle = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('Styled content'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );

    expect(titleDefaultTextStyle.style, titleStyle);
    expect(contentDefaultTextStyle.style, contentStyle);
  });

  testWidgets('android dialogs use default alert semantics and action layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData.copyWith(platform: TargetPlatform.android),
        home: const Scaffold(
          body: CustomAlertDialog(
            title: Text('Android title'),
            content: Text('Android content'),
            buttonPadding: EdgeInsets.symmetric(horizontal: 24),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actionsOverflowAlignment: OverflowBarAlignment.center,
            actionsOverflowDirection: VerticalDirection.up,
            actionsOverflowButtonSpacing: 6,
            actions: [
              TextButton(onPressed: null, child: Text('Later')),
              TextButton(onPressed: null, child: Text('OK')),
            ],
          ),
        ),
      ),
    );

    final overflowBar = tester.widget<OverflowBar>(find.byType(OverflowBar));

    expect(find.bySemanticsLabel('Alert'), findsOneWidget);
    expect(overflowBar.alignment, MainAxisAlignment.spaceBetween);
    expect(overflowBar.spacing, 24);
    expect(overflowBar.overflowAlignment, OverflowBarAlignment.center);
    expect(overflowBar.overflowDirection, VerticalDirection.up);
    expect(overflowBar.overflowSpacing, 6);
  });

  testWidgets('default dialog styles come from the active material theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        home: const Scaffold(
          body: CustomAlertDialog(
            title: Text('Default title'),
            content: Text('Default content'),
          ),
        ),
      ),
    );

    final titleDefaultTextStyle = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('Default title'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    final contentDefaultTextStyle = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('Default content'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );

    expect(titleDefaultTextStyle.style.fontWeight, FontWeight.w600);
    expect(contentDefaultTextStyle.style.fontSize, 14);
    expect(contentDefaultTextStyle.style.fontWeight, FontWeight.w400);
  });
}
