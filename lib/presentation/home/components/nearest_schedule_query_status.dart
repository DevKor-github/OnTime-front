import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/schedule/schedule_bloc.dart';

/// Query progress is not an empty calendar or permission to start preparation.
class NearestScheduleQueryStatus extends StatelessWidget {
  const NearestScheduleQueryStatus({
    super.key,
    required this.query,
    this.showStaleNotice = true,
  });

  final NearestScheduleQuery query;
  final bool showStaleNotice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final key = query.key;
    final limited = query is NearestQueryLimited
        ? query as NearestQueryLimited
        : null;
    final loading = query is NearestQueryLoading;
    final failed = query is NearestQueryError;
    final showCalendar = limited != null || query.issues.isNotEmpty;
    final String? message;
    if (loading || query is NearestQueryIdle) {
      message = l10n.homeCheckingAppointments;
    } else if (failed) {
      message = l10n.homeQueryFailed;
    } else if (limited != null) {
      message = switch (limited.reason) {
        NearestQueryLimitReason.cancelled => l10n.homeQueryCancelled,
        NearestQueryLimitReason.interrupted => l10n.homeQueryInterrupted,
        _ => l10n.homeQueryLimited,
      };
    } else {
      message = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message != null) Semantics(liveRegion: true, child: Text(message)),
        if (showStaleNotice && query.stale != null) Text(l10n.homeQueryStale),
        if (query.issues.isNotEmpty) Text(l10n.homeTimeIssues),
        Wrap(
          spacing: 8,
          children: [
            if (key != null && loading)
              TextButton.icon(
                key: const Key('cancel-nearest-query'),
                onPressed: () => context.read<ScheduleBloc>().add(
                  ScheduleNearestQueryCancelRequested(key),
                ),
                icon: const Icon(Icons.close),
                label: Text(l10n.homeCancelQuery),
              ),
            if (key != null && (failed || limited?.canRetry == true))
              TextButton.icon(
                key: const Key('retry-upcoming-schedule'),
                onPressed: () => context.read<ScheduleBloc>().add(
                  ScheduleNearestQueryRetryRequested(key),
                ),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.homeRetryQuery),
              ),
            if (key != null && limited?.canContinue == true)
              TextButton.icon(
                key: const Key('continue-nearest-query'),
                onPressed: () => context.read<ScheduleBloc>().add(
                  ScheduleNearestQueryContinueRequested(key),
                ),
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.homeContinueQuery),
              ),
            if (showCalendar)
              TextButton.icon(
                key: const Key('nearest-query-calendar'),
                onPressed: () => context.go('/calendar'),
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(l10n.homeReviewCalendar),
              ),
          ],
        ),
      ],
    );
  }
}
