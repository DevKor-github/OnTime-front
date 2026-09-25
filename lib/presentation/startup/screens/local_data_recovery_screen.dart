import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/domain/entities/local_reset_result.dart';
import 'package:on_time_front/presentation/startup/screens/local_reset_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:on_time_front/domain/use-cases/local_data_workflows.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';

class LocalDataRecoveryScreen extends StatefulWidget {
  const LocalDataRecoveryScreen({
    super.key,
    this.reset,
    this.onRetry,
    this.onResetComplete,
  });
  final Future<LocalResetResult> Function()? reset;
  final VoidCallback? onRetry;
  final VoidCallback? onResetComplete;
  @override
  State<LocalDataRecoveryScreen> createState() =>
      _LocalDataRecoveryScreenState();
}

class _LocalDataRecoveryScreenState extends State<LocalDataRecoveryScreen> {
  bool _busy = false;
  String? _error;
  LocalResetResult? _resetResult;
  @override
  Widget build(BuildContext context) {
    final resetResult = _resetResult;
    if (resetResult != null) {
      return LocalResetProgressScreen(
        initialResult: resetResult,
        operation: widget.reset ?? getIt<LocalResetWorkflow>().call,
      );
    }
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        body: RecurrenceSheet(
          title: '데이터 복구',
          showBack: false,
          footer: _busy
              ? const Column(
                  children: [
                    ModalWideButton(
                      onPressed: null,
                      text: '다시 시도',
                      layout: ModalWideButtonLayout.full,
                      height: 44,
                    ),
                    SizedBox(height: 8),
                    ModalWideButton(
                      onPressed: null,
                      text: '초기화 실행',
                      layout: ModalWideButtonLayout.full,
                      height: 44,
                    ),
                  ],
                )
              : null,
          children: _busy
              ? [
                  SizedBox(height: MediaQuery.sizeOf(context).height * .30),
                  const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '로컬 데이터 초기화 중',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    '처리가 끝날 때까지 잠시 기다려 주세요.',
                    textAlign: TextAlign.center,
                  ),
                ]
              : [
                  const SizedBox(height: 36),
                  Center(
                    child: SvgPicture.asset(
                      'assets/design/recovery_warning.svg',
                      width: 68,
                      height: 68,
                    ),
                  ),
                  const Text(
                    '기기에서 로컬 데이터를\n열 수 없습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    '기기에서 데이터를 열거나 마이그레이션할 수 없는 상태입니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 4),
                  const RecurrencePanel(
                    highlighted: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '데이터는 자동으로 삭제되지 않았습니다.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '기기에 그대로 보존되어 있으니, 아래 방법을 시도해 주세요.',
                          style: TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  ModalWideButton(
                    text: '다시 시도하기',
                    layout: ModalWideButtonLayout.full,
                    variant: ModalWideButtonVariant.primary,
                    height: 44,
                    onPressed:
                        widget.onRetry ??
                        () => context.read<AuthBloc>().add(
                          const AuthUserSubscriptionRequested(),
                        ),
                  ),
                  ModalWideButton(
                    text: '모든 로컬 데이터 초기화',
                    layout: ModalWideButtonLayout.full,
                    variant: ModalWideButtonVariant.subtle,
                    height: 44,
                    onPressed: _confirmReset,
                  ),
                  const RecurrencePanel(
                    child: Text(
                      '위 방법으로도 복구할 수 없는 경우,\n기기의 모든 로컬 데이터를 초기화할 수 있습니다.\n\n원격 복구나 로그인 기능은 제공하지 않습니다.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    if (_busy) return;
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LocalDataResetConfirmationScreen(),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await (widget.reset ?? getIt<LocalResetWorkflow>().call)();
      if (!mounted) return;
      if (result.isComplete && widget.onResetComplete != null) {
        widget.onResetComplete!();
      } else {
        setState(() => _resetResult = result);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('ko')))
                  .dataResetFailed;
        });
      }
    }
  }
}

class LocalDataResetConfirmationScreen extends StatelessWidget {
  const LocalDataResetConfirmationScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: RecurrenceSheet(
      title: '데이터 초기화',
      footer: ScreenActions(
        action: '모두 삭제',
        destructive: true,
        backLabel: '취소',
        onBack: () => Navigator.of(context).pop(false),
        onAction: () => Navigator.of(context).pop(true),
      ),
      children: [
        const SizedBox(height: 48),
        Text(
          '복구하지 않고 삭제하시겠습니까?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          '이 설치의 모든 로컬 데이터와 암호화 키가 삭제됩니다. 삭제된 데이터는 되돌릴 수 없습니다.',
          style: TextStyle(height: 1.6),
        ),
        const RecurrencePanel(
          child: Text(
            '•  이 기기에 저장된 모든 데이터가 삭제됩니다.\n\n•  암호화 키도 함께 삭제되어 복구할 수 없습니다.\n\n•  이 작업은 되돌릴 수 없습니다.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        const RecurrencePanel(
          highlighted: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '백업 파일은 직접 삭제해야 합니다.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                '다른 기기나 클라우드 등 외부에 저장한 백업 파일은 이 작업으로 삭제되지 않습니다. 필요 시 직접 삭제해 주세요.',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
