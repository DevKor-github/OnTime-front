// Synthetic receipt rendering, not mobile DB or notification-delivery proof.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/entities/default_preferences.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/my_page/preparation_spare_time_edit/bloc/default_preparation_spare_time_form_bloc.dart';
import 'package:on_time_front/presentation/my_page/preparation_spare_time_edit/preparation_spare_time_edit_screen.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import '../../test/presentation/my_page/preparation_spare_time_edit/preparation_spare_time_edit_screen_test.dart'
    show TestPreferencesWorkflow;

void main() {
  testWidgets('KO EN 200 percent default preference receipt states', (
    tester,
  ) async {
    final output = Directory('/tmp/c01-defaults-ui');
    await tester.runAsync(() => output.create(recursive: true));
    final font = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    await tester.runAsync(font.load);
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final language in ['ko', 'en']) {
      for (final state in [
        'load-failed',
        'save-failed',
        'conflict',
        'reload-pending',
        'delivery-pending',
        'both-pending',
        'authority-pending',
        'expired',
      ]) {
        await getIt.reset();
        final workflow = TestPreferencesWorkflow();
        if (state == 'load-failed') {
          workflow.readHandler = () async => throw StateError('synthetic');
        }
        workflow.saveHandler = (_) async {
          if (state == 'save-failed') {
            throw const DefaultPreferencesRejected(
              DefaultPreferencesFailure.failed,
            );
          }
          if (state == 'conflict') {
            throw const DefaultPreferencesRejected(
              DefaultPreferencesFailure.conflict,
            );
          }
          return workflow
              .receipt(
                reload: state == 'reload-pending' || state == 'both-pending',
                delivery:
                    state == 'delivery-pending' || state == 'both-pending',
              )
              .withFollowUp(
                reloadPending:
                    state == 'reload-pending' || state == 'both-pending',
                deliveryPending:
                    state == 'delivery-pending' || state == 'both-pending',
                authorityPending: state == 'authority-pending',
                superseded: state == 'expired',
              );
        };
        getIt.registerFactory<DefaultPreparationSpareTimeFormBloc>(
          () => DefaultPreparationSpareTimeFormBloc(workflow),
        );
        getIt.registerFactory<PreparationFormBloc>(PreparationFormBloc.new);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: themeData,
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const PreparationSpareTimeEditScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (state != 'load-failed') {
          await tester.tap(find.byType(TextButton).first);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${output.path}/$state-$language.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    }
    await getIt.reset();
  });
}
