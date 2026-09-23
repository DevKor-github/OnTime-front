import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/database/local_data_reset_service.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';

class LocalDataRecoveryScreen extends StatefulWidget {
  const LocalDataRecoveryScreen({super.key});

  @override
  State<LocalDataRecoveryScreen> createState() =>
      _LocalDataRecoveryScreenState();
}

class _LocalDataRecoveryScreenState extends State<LocalDataRecoveryScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  // The action has a 48px touch target while its Figma label
                  // occupies only 21px. Balance the extra hit area below it.
                  padding: const EdgeInsets.fromLTRB(24, 27, 24, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 77, child: _StorageSymbol()),
                      const SizedBox(height: 18),
                      Text(
                        '로컬 데이터를 열 수 없습니다.',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 336),
                        child: const Text(
                          'OnTime은 데이터를 자동으로 삭제하지 않았습니다. 잠시 후\n'
                          '다시 시도하거나, 복구할 수 없는 경우에만 모든 로컬 데이터를\n'
                          '초기화하세요.',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            height: 1.2,
                            letterSpacing: -0.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () {
                                context.read<AuthBloc>().add(
                                  const AuthUserSubscriptionRequested(),
                                );
                              },
                        style: FilledButton.styleFrom(
                          fixedSize: const Size(112, 47),
                          padding: EdgeInsets.zero,
                          backgroundColor: const Color(0xFF536AE8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('다시 시도'),
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: _busy ? null : _confirmReset,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD6362B),
                          minimumSize: const Size(214, 48),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.topLeft,
                          textStyle: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('모든 로컬 데이터 초기화'),
                      ),
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final result = await showTwoActionDialog(
      context,
      config: const TwoActionDialogConfig(
        title: '복구하지 않고 삭제할까요?',
        description: '현재 설치의 모든 데이터와 암호화 키가 삭제되며 되돌릴 수 없습니다.',
        secondaryAction: DialogActionConfig(label: '취소'),
        primaryAction: DialogActionConfig(
          label: '모두 삭제',
          variant: ModalWideButtonVariant.primary,
        ),
        barrierColor: Color(0x6B000000),
        alignment: Alignment(0, 0.04),
      ),
    );
    if (result != DialogActionResult.primary) return;
    setState(() => _busy = true);
    try {
      await getIt<LocalDataResetService>().reset();
      if (mounted) context.go('/resetComplete');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로컬 데이터를 초기화하지 못했습니다. 다시 시도해주세요.')),
      );
    }
  }
}

/// The Figma Material Symbols Rounded storage mark has taller bars and round
/// dots than Flutter's similarly named Material Icons glyph.
class _StorageSymbol extends StatelessWidget {
  const _StorageSymbol();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(64, 77),
    painter: const _StorageSymbolPainter(),
  );
}

class _StorageSymbolPainter extends CustomPainter {
  const _StorageSymbolPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xFF111111);
    final cutout = Paint()..color = Colors.white;
    for (final top in <double>[13.5, 32.5, 50.5]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(6, top, 52, 13.5),
          const Radius.circular(6.75),
        ),
        fill,
      );
      canvas.drawCircle(Offset(14.5, top + 6.75), 3, cutout);
    }
  }

  @override
  bool shouldRepaint(covariant _StorageSymbolPainter oldDelegate) => false;
}
