import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadVisualTestFonts() async {
  final regular = await rootBundle.load('assets/fonts/Pretendard-Regular.ttf');
  final semiBold = await rootBundle.load(
    'assets/fonts/Pretendard-SemiBold.ttf',
  );
  final bold = await rootBundle.load('assets/fonts/Pretendard-Bold.ttf');
  await (FontLoader('Pretendard')
        ..addFont(Future.value(regular))
        ..addFont(Future.value(semiBold))
        ..addFont(Future.value(bold)))
      .load();

  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final iconBytes = await File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytes();
  await (FontLoader('MaterialIcons')..addFont(
        Future.value(ByteData.sublistView(Uint8List.fromList(iconBytes))),
      ))
      .load();
}
