import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

void main() {
  test('copyWith keeps existing tile style values when not overridden', () {
    const style = TileStyle(
      backgroundColor: Colors.red,
      borderRadius: BorderRadius.all(Radius.circular(8)),
      minimumSize: Size(10, 20),
      maximumSize: Size(100, 200),
      padding: EdgeInsets.all(4),
      margin: EdgeInsets.all(2),
    );

    final copied = style.copyWith(backgroundColor: Colors.blue);

    expect(copied.backgroundColor, Colors.blue);
    expect(copied.borderRadius, style.borderRadius);
    expect(copied.minimumSize, style.minimumSize);
    expect(copied.maximumSize, style.maximumSize);
    expect(copied.padding, style.padding);
    expect(copied.margin, style.margin);
  });

  test('lerp interpolates all tile style dimensions', () {
    const start = TileStyle(
      backgroundColor: Colors.red,
      borderRadius: BorderRadius.all(Radius.circular(4)),
      minimumSize: Size(10, 20),
      maximumSize: Size(100, 200),
      padding: EdgeInsets.all(4),
      margin: EdgeInsets.all(2),
    );
    const end = TileStyle(
      backgroundColor: Colors.blue,
      borderRadius: BorderRadius.all(Radius.circular(12)),
      minimumSize: Size(20, 40),
      maximumSize: Size(200, 400),
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.all(6),
    );

    final mid = start.lerp(end, 0.5);

    expect(mid.backgroundColor, Color.lerp(Colors.red, Colors.blue, 0.5));
    expect(
      mid.borderRadius,
      BorderRadius.lerp(start.borderRadius, end.borderRadius, 0.5),
    );
    expect(mid.minimumSize, const Size(15, 30));
    expect(mid.maximumSize, const Size(150, 300));
    expect(
      mid.padding,
      EdgeInsetsGeometry.lerp(start.padding, end.padding, 0.5),
    );
    expect(mid.margin, EdgeInsetsGeometry.lerp(start.margin, end.margin, 0.5));
    expect(start.lerp(null, 0.5), start);
    expect(mid.toString(), contains('TileStyle'));
  });
}
