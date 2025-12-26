import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

extension FailureMessage on Failure {
  /// Converts a [Failure] to a user-facing message.
  ///
  /// - In debug: include `code` + `message` (fast iteration).
  /// - In release: show localized friendly messages.
  String toUserMessage(BuildContext context) {
    if (kDebugMode) {
      return '$code: $message';
    }

    final l10n = AppLocalizations.of(context)!;

    return switch (this) {
      NetworkFailure() => l10n.error,
      ValidationFailure() => message,
      DataIntegrityFailure() => l10n.error,
      _ => l10n.error,
    };
  }
}


