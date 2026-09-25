import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/database/local_data_reset_service.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/my_page/data_state_page.dart';
import 'package:on_time_front/presentation/shared/components/app_spinner.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';

class LocalDataRecoveryScreen extends StatefulWidget {
  const LocalDataRecoveryScreen({
    super.key,
    this.reset,
    this.onRetry,
    this.onResetComplete,
  });
  final Future<void> Function()? reset;
  final VoidCallback? onRetry;
  final VoidCallback? onResetComplete;
  @override
  State<LocalDataRecoveryScreen> createState() =>
      _LocalDataRecoveryScreenState();
}

class _LocalDataRecoveryScreenState extends State<LocalDataRecoveryScreen> {
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: DataStatePage(
      title: '데이터 복구',
      showBack: false,
      footerPadding: const EdgeInsets.fromLTRB(17, 16, 17, 23),
      footer: _busy
          ? Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(
                  context,
                ).colorScheme.copyWith(surfaceDim: const Color(0xFF949494)),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ModalWideButton(
                    onPressed: null,
                    text: '다시 시도',
                    variant: ModalWideButtonVariant.primary,
                    layout: ModalWideButtonLayout.full,
                    height: 44,
                  ),
                  SizedBox(height: 10),
                  ModalWideButton(
                    onPressed: null,
                    text: '초기화 실행',
                    variant: ModalWideButtonVariant.primary,
                    layout: ModalWideButtonLayout.full,
                    height: 44,
                  ),
                ],
              ),
            )
          : null,
      children: _busy
          ? [
              SizedBox(
                height: (MediaQuery.sizeOf(context).height * .287).clamp(
                  100,
                  242,
                ),
              ),
              const Center(
                child: SizedBox(
                  height: 47,
                  width: 47,
                  child: Center(
                    child: AppSpinner(
                      assetPath: 'assets/design/recovery_spinner.svg',
                      assetPackage: null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '로컬 데이터 초기화 중',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                '처리가 끝날 때까지 잠시 기다려 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: Color(0xFF545454),
                ),
              ),
            ]
          : [
              const SizedBox(height: 52),
              Center(
                child: SvgPicture.asset(
                  'assets/design/recovery_warning.svg',
                  width: 68,
                  height: 68,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '기기에서 로컬 데이터를\n열 수 없습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  height: 30 / 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                '기기에서 데이터를 열거나 마이그레이션할 수 없는\n상태입니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF545454),
                ),
              ),
              const SizedBox(height: 27),
              const DataNotice(
                key: Key('recoveryPreservedNotice'),
                highlighted: true,
                padding: EdgeInsets.fromLTRB(15, 15, 15, 12),
                gap: 13,
                minHeight: 69,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '데이터는 자동으로 삭제되지 않았습니다.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.6,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF212F6F),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '기기에 그대로 보존되어 있으니, 아래 방법을 시도해 주세요.',
                      style: TextStyle(
                        fontSize: 11.2,
                        height: 18 / 11.2,
                        color: Color(0xFF545454),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
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
              const SizedBox(height: 8),
              ModalWideButton(
                text: '모든 로컬 데이터 초기화',
                layout: ModalWideButtonLayout.full,
                variant: ModalWideButtonVariant.subtle,
                height: 44,
                onPressed: _confirmReset,
              ),
              const SizedBox(height: 25),
              Container(
                padding: const EdgeInsets.fromLTRB(19, 16, 19, 17),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  '위 방법으로도 복구할 수 없는 경우,\n기기의 모든 로컬 데이터를 초기화할 수 있습니다.\n\n원격 복구나 로그인 기능은 제공하지 않습니다.',
                  style: TextStyle(
                    fontSize: 11.3,
                    height: 15.5 / 11.3,
                    color: Color(0xFF545454),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
    ),
  );

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
      await (widget.reset ?? getIt<LocalDataResetService>().reset)();
      if (!mounted) return;
      if (widget.onResetComplete != null) {
        widget.onResetComplete!();
      } else {
        context.go('/resetComplete');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '초기화하지 못했습니다. 다시 시도해 주세요.';
        });
      }
    }
  }
}

class LocalDataResetConfirmationScreen extends StatelessWidget {
  const LocalDataResetConfirmationScreen({super.key});
  @override
  Widget build(BuildContext context) => DataStatePage(
    title: '데이터 초기화',
    footer: Row(
      children: [
        Expanded(
          child: ModalWideButton(
            text: '취소',
            variant: ModalWideButtonVariant.subtle,
            layout: ModalWideButtonLayout.full,
            height: 48,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        const SizedBox(width: 11.5),
        Expanded(
          child: ModalWideButton(
            text: '모두 삭제',
            variant: ModalWideButtonVariant.destructive,
            layout: ModalWideButtonLayout.full,
            height: 48,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
      ],
    ),
    children: [
      const SizedBox(height: 36),
      Row(
        children: [
          SvgPicture.asset(
            'assets/design/destructive_warning.svg',
            width: 47,
            height: 47,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              '복구하지 않고 삭제하시겠습니까?',
              style: TextStyle(
                fontSize: 19,
                height: 27 / 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const Text(
        '이 설치의 모든 로컬 데이터와 암호화 키가 삭제됩니다.\n삭제된 데이터는 되돌릴 수 없습니다.',
        style: TextStyle(
          fontSize: 14.8,
          height: 23 / 14.8,
          color: Color(0xFF545454),
        ),
      ),
      const SizedBox(height: 23),
      Container(
        key: const Key('resetConsequences'),
        padding: const EdgeInsets.fromLTRB(18, 11, 18, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Text(
          '•   이 기기에 저장된 모든 데이터가 삭제됩니다.\n•   암호화 키도 함께 삭제되어 복구할 수 없습니다.\n•   이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(fontSize: 13.5, height: 29 / 13.5),
        ),
      ),
      const SizedBox(height: 22),
      const DataNotice(
        key: Key('resetExternalBackupNotice'),
        highlighted: true,
        padding: EdgeInsets.fromLTRB(17, 17, 17, 14),
        minHeight: 93,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '백업 파일은 직접 삭제해야 합니다.',
              style: TextStyle(
                fontSize: 13.7,
                height: 21 / 13.7,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212F6F),
              ),
            ),
            SizedBox(height: 5),
            Text(
              '다른 기기나 클라우드 등 외부에 저장한 백업 파일은\n이 작업으로 삭제되지 않습니다. 필요 시 직접 삭제해 주세요.',
              style: TextStyle(
                fontSize: 11.2,
                height: 18 / 11.2,
                color: Color(0xFF545454),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
}
