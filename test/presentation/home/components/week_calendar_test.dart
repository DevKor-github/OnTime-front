import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/home/components/week_calendar.dart';

void main() {
  test('firstDayOfWeek resolves to Monday for the selected week', () {
    final calendar = WeekCalendar(
      date: DateTime(2026, 5, 15),
      highlightedDates: const [],
      onDateSelected: (_) {},
    );

    expect(calendar.firstDayOfWeek, DateTime.utc(2026, 5, 11));
  });

  testWidgets('renders one week and reports the tapped date', (tester) async {
    DateTime? selectedDate;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [DateTileThemeData(style: _dateTileStyle())],
        ),
        home: Scaffold(
          body: WeekCalendar(
            date: DateTime(2026, 5, 15),
            highlightedDates: [DateTime(2026, 5, 13)],
            onDateSelected: (date) => selectedDate = date,
          ),
        ),
      ),
    );

    expect(find.text('월'), findsOneWidget);
    expect(find.text('일'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);

    await tester.tap(find.text('13'));
    await tester.pump();

    expect(selectedDate, DateTime.utc(2026, 5, 13));
  });

  testWidgets('disabled date tile does not invoke tap callback', (
    tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateTile(
            date: DateTime(2026, 5, 15),
            onTap: null,
            style: _dateTileStyle(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('15'));
    await tester.pump();

    expect(tapCount, 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DateTile(
            date: DateTime(2026, 5, 15),
            onTap: () => tapCount += 1,
            style: _dateTileStyle(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('15'));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('date tile theme supplies visual style defaults', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [DateTileThemeData(style: _dateTileStyle())],
        ),
        home: Scaffold(
          body: DateTile.outlined(date: DateTime(2026, 5, 16), onTap: () {}),
        ),
      ),
    );

    final material = tester.widget<Material>(find.byType(Material).last);
    expect(material.color, Colors.yellow);
    expect(material.textStyle!.color, Colors.black);
  });

  testWidgets('filled date tile uses built-in selected-day colors', (
    tester,
  ) async {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: colorScheme,
          extensions: [
            DateTileThemeData(
              style: DateTileStyle(
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 16),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        home: Scaffold(
          body: DateTile.filled(date: DateTime(2026, 5, 15), onTap: () {}),
        ),
      ),
    );

    final material = tester.widget<Material>(find.byType(Material).last);

    expect(material.color, colorScheme.primary);
    expect(material.textStyle!.color, colorScheme.onPrimary);
  });

  test('date tile style copy, merge, equality, and lerp are stable', () {
    final base = _dateTileStyle(backgroundColor: Colors.white);
    final override = _dateTileStyle(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      sideColor: Colors.red,
    );

    final copied = base.copyWith(
      backgroundColor: WidgetStateProperty.all(Colors.green),
    );
    final merged = base.merge(override);
    final lerped = DateTileStyle.lerp(base, override, 0.5)!;
    final themeData = DateTileThemeData(style: base);

    expect(copied.backgroundColor!.resolve({}), Colors.green);
    expect(merged.backgroundColor!.resolve({}), Colors.white);
    expect(merged.forgroundColor!.resolve({}), Colors.black);
    expect(lerped.backgroundColor!.resolve({}), isA<Color>());
    expect(DateTileStyle.lerp(base, base, 0.5), same(base));
    expect(
      DateTileStyle.lerp(const DateTileStyle(), const DateTileStyle(), 0.5),
      isA<DateTileStyle>(),
    );
    expect(themeData.copyWith(), DateTileThemeData(style: base));
    expect(
      themeData.lerp(DateTileThemeData(style: override), 0.5),
      isA<DateTileThemeData>(),
    );
    expect(themeData.hashCode, DateTileThemeData(style: base).hashCode);
  });
}

DateTileStyle _dateTileStyle({
  Color backgroundColor = Colors.yellow,
  Color foregroundColor = Colors.black,
  Color sideColor = Colors.blue,
}) {
  return DateTileStyle(
    textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 16)),
    backgroundColor: WidgetStateProperty.all(backgroundColor),
    forgroundColor: WidgetStateProperty.all(foregroundColor),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    side: WidgetStateProperty.all(BorderSide(color: sideColor)),
  );
}
