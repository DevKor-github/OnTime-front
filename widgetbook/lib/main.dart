import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

// This file does not exist yet,
// it will be generated in the next step
import 'main.directories.g.dart';

void main() {
  configureDependencies();
  runApp(const WidgetbookApp());
}

@widgetbook.App()
class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      // The [directories] variable does not exist yet,
      // it will be generated in the next step
      directories: directories,
      addons: [
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(name: 'Light', data: themeData),
            WidgetbookTheme(name: 'Dark', data: ThemeData.dark()),
          ],
        ),
        TextScaleAddon(
          min: 0.5,
          max: 4,
        ),
        LocalizationAddon(
          locales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
        DeviceFrameAddon(
          devices: Devices.ios.all,
          initialDevice: Devices.ios.iPhone13,
        ),
        BuilderAddon(
          name: 'background',
          builder: (context, child) {
            final mediaQuery = MediaQuery.maybeOf(context);
            final wrappedChild = mediaQuery == null
                ? child
                : MediaQuery(
                    data: mediaQuery.copyWith(
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                    ),
                    child: child,
                  );

            return Container(
              height: double.infinity,
              width: double.infinity,
              color: Colors.white,
              child: wrappedChild,
            );
          },
        ),
        AlignmentAddon(
          initialAlignment: Alignment.center,
        ),
      ],
    );
  }
}
