import 'package:flutter/material.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

class MovingScreen extends StatelessWidget {
  const MovingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text(AppLocalizations.of(context)!.movingScreenTitle),
    );
  }
}
