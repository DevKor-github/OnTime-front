import 'dart:async';
import 'package:flutter/material.dart';
import 'package:on_time_front/core/database/local_reset_protocol.dart';
import 'package:on_time_front/l10n/app_localizations.dart';

/// A pending platform Future remains owned by the service after the UI's wait
/// notice. It is neither canceled nor replaced by a second reset operation.
class LocalResetProgressScreen extends StatefulWidget {
  const LocalResetProgressScreen({
    super.key,
    required this.operation,
    this.initialResult,
    this.waitNoticeAfter = const Duration(seconds: 10),
  });
  final Future<LocalResetResult> Function() operation;
  final LocalResetResult? initialResult;
  final Duration waitNoticeAfter;
  @override
  State<LocalResetProgressScreen> createState() =>
      _LocalResetProgressScreenState();
}

class _LocalResetProgressScreenState extends State<LocalResetProgressScreen> {
  LocalResetResult? _result;
  bool _busy = false;
  bool _waiting = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
    if (_result == null) unawaited(_run());
  }

  Future<void> _run() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _waiting = false;
    });
    _timer = Timer(widget.waitNoticeAfter, () {
      if (mounted && _busy) setState(() => _waiting = true);
    });
    try {
      final result = await widget.operation();
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => _result ??= const LocalResetResult(
            intentRecorded: false,
            completed: {},
          ),
        );
      }
    } finally {
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _busy = false;
          _waiting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = _result;
    final complete = result?.isComplete == true;
    final body = _waiting
        ? l10n.resetWaitingBody
        : _busy
        ? l10n.resetInProgressBody
        : complete
        ? l10n.resetCompleteBody
        : result?.dataDeleted == true
        ? l10n.resetDeletedPendingBody
        : result?.intentRecorded == true
        ? l10n.resetIncompleteBody
        : l10n.resetNoIntentBody;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      complete
                          ? Icons.check_circle_outline
                          : Icons.storage_rounded,
                      size: 56,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      complete
                          ? l10n.resetCompleteTitle
                          : l10n.resetInProgressTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(body, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    if (_busy) const CircularProgressIndicator(),
                    if (!_busy && !complete)
                      FilledButton(
                        onPressed: _run,
                        child: Text(l10n.resetRetryAction),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
