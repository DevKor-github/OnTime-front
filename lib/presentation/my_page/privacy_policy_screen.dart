import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const sections = <(String, String)>[
    (
      '저장되는 정보',
      'OnTime은 사용자가 입력한 일정, 장소, 준비 단계, 시간 기록, 정시 도착 집계와 앱 설정을 현재 기기의 암호화된 로컬 저장소에 보관합니다. 이름, 이메일, 소셜 로그인 정보나 서버 계정을 수집하지 않습니다.',
    ),
    (
      '외부 전송',
      'OnTime은 앱 사용 데이터, 분석 이벤트, 인증 정보 또는 푸시 토큰을 OnTime 서버나 분석 서비스로 전송하지 않습니다. 알림과 알람은 운영체제의 기기 내 기능으로 예약됩니다.',
    ),
    (
      '백업',
      '백업은 사용자가 직접 실행할 때만 생성됩니다. 백업 파일은 사용자가 지정한 위치에 저장되며, 사용자가 입력한 백업 비밀번호로 암호화됩니다. OnTime은 비밀번호나 백업 파일 위치를 저장하지 않으므로 분실한 비밀번호를 복구할 수 없습니다.',
    ),
    (
      '삭제',
      '내 데이터 화면의 로컬 데이터 초기화를 실행하면 이 설치가 소유한 데이터, 알람 등록 정보와 기기 암호화 키가 삭제됩니다. 사용자가 외부 위치로 내보낸 백업 파일은 직접 삭제해야 합니다.',
    ),
    (
      '운영체제 기능',
      '파일 선택, 로컬 알림, 알람과 앱 권한 처리는 Android 또는 iOS가 제공합니다. 운영체제나 사용자가 선택한 외부 파일 제공자의 처리에는 해당 서비스의 정책이 적용됩니다.',
    ),
    ('문의', '앱 배포 페이지에 표시된 개발자 연락처를 이용할 수 있습니다.'),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: RecurrenceSheet(
      title: '개인정보 처리방침',
      spacing: 8,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text('시행일: 2026년 8월 28일', style: TextStyle(fontSize: 12)),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text('OnTime 로컬 전용 개인정보 처리방침', style: TextStyle(fontSize: 14)),
        ),
        for (var i = 0; i < sections.length; i++)
          RecurrencePanel(
            child: SelectionArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sections[i].$1,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sections[i].$2,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
