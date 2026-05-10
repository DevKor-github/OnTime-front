import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:on_time_front/core/constants/external_links.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/core/services/alarm_scheduler_service.dart';
import 'package:on_time_front/core/services/fallback_alarm_notification_service.dart';
import 'package:on_time_front/domain/entities/alarm_entities.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/alarm_registry_repository.dart';
import 'package:on_time_front/domain/repositories/alarm_repository.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';
import 'package:on_time_front/presentation/my_page/my_page_screen.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
    getIt
      ..registerSingleton<AlarmRepository>(_FakeAlarmRepository())
      ..registerSingleton<AlarmRegistryRepository>(_FakeAlarmRegistry())
      ..registerSingleton<AlarmSchedulerService>(_FakeAlarmSchedulerService())
      ..registerSingleton<FallbackAlarmNotificationService>(
        _FakeFallbackAlarmNotificationService(),
      );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('shows English privacy policy setting', (tester) async {
    await _pumpMyPage(tester, locale: const Locale('en'));

    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('shows Korean privacy policy setting', (tester) async {
    await _pumpMyPage(tester, locale: const Locale('ko'));

    expect(find.text('개인정보 처리방침'), findsOneWidget);
  });

  testWidgets('opens hosted privacy policy URL from setting', (tester) async {
    final openedUris = <Uri>[];

    await _pumpMyPage(
      tester,
      locale: const Locale('en'),
      openPrivacyPolicy: (uri) async {
        openedUris.add(uri);
        return true;
      },
    );

    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(openedUris, [ExternalLinks.privacyPolicyUri]);
  });
}

Future<void> _pumpMyPage(
  WidgetTester tester, {
  required Locale locale,
  PrivacyPolicyLauncher? openPrivacyPolicy,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: themeData,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<AuthBloc>.value(
        value: _StubAuthBloc(),
        child: MyPageScreen(openPrivacyPolicy: openPrivacyPolicy),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _StubAuthBloc extends Mock implements AuthBloc {
  @override
  AuthState get state => const AuthState.loading();

  @override
  Stream<AuthState> get stream => const Stream.empty();

  @override
  bool get isClosed => false;
}

class _FakeAlarmRepository implements AlarmRepository {
  @override
  Future<String> getDeviceId() => throw UnimplementedError();

  @override
  Future<AlarmDeviceInfo> buildCurrentDeviceInfo() =>
      throw UnimplementedError();

  @override
  Future<AlarmSettings> getAlarmSettings() async {
    return const AlarmSettings(alarmsEnabled: false);
  }

  @override
  Future<AlarmSettings> updateAlarmSettings({required bool alarmsEnabled}) {
    throw UnimplementedError();
  }

  @override
  Future<void> registerCurrentDevice(AlarmDeviceInfo deviceInfo) {
    throw UnimplementedError();
  }

  @override
  Future<void> unregisterCurrentDevice(String deviceId) {
    throw UnimplementedError();
  }

  @override
  Future<List<ScheduleWithPreparationEntity>> getAlarmWindow(
    DateTime startDate,
    DateTime endDate,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> postAlarmStatus(AlarmStatusReport report) {
    throw UnimplementedError();
  }
}

class _FakeAlarmRegistry implements AlarmRegistryRepository {
  @override
  Future<List<ScheduledAlarmRecord>> loadAll() async => const [];

  @override
  Future<void> upsert(ScheduledAlarmRecord record) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteByScheduleId(String scheduleId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAll() {
    throw UnimplementedError();
  }

  @override
  Future<void> replaceAll(List<ScheduledAlarmRecord> records) {
    throw UnimplementedError();
  }
}

class _FakeAlarmSchedulerService extends AlarmSchedulerService {
  @override
  Future<AlarmSchedulerCapabilities> getCapabilities() async {
    return AlarmSchedulerCapabilities.unsupported;
  }

  @override
  Future<AlarmPermissionState> checkPermission() async {
    return AlarmPermissionState.unsupported;
  }
}

class _FakeFallbackAlarmNotificationService
    implements FallbackAlarmNotificationService {
  @override
  Future<AlarmPermissionState> checkPermission() async {
    return AlarmPermissionState.unsupported;
  }

  @override
  Future<AlarmPermissionState> requestPermission() {
    throw UnimplementedError();
  }

  @override
  Future<void> scheduleFallbackAlarm(ScheduledAlarmRecord record) {
    throw UnimplementedError();
  }

  @override
  Future<void> cancelFallbackAlarm(ScheduledAlarmRecord record) {
    throw UnimplementedError();
  }
}
