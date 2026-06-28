import 'package:on_time_front/domain/entities/schedule_preparation_mode.dart';

class ProductUsageEvent {
  ProductUsageEvent._({
    required ProductUsageEventDefinition definition,
    required ProductUsageResult eventResult,
    Map<String, Object> parameters = const {},
  }) : name = definition.name,
       workflow = definition.workflow.wireValue,
       result = eventResult.wireValue,
       schemaVersion = definition.schemaVersion,
       parameters = ProductUsageEventCatalog.validateParameters(
         definition,
         parameters,
       );

  factory ProductUsageEvent.fromCatalog({
    required String name,
    required ProductUsageResult result,
    Map<String, Object> parameters = const {},
  }) {
    final definition = ProductUsageEventCatalog.definitionFor(name);
    return ProductUsageEvent._(
      definition: definition,
      eventResult: result,
      parameters: parameters,
    );
  }

  factory ProductUsageEvent.scheduleCreated({
    required SchedulePreparationMode? preparationMode,
    required int preparationStepCount,
    required int minutesUntilSchedule,
  }) {
    return ProductUsageEvent._(
      definition: ProductUsageEventCatalog.scheduleCreated,
      eventResult: ProductUsageResult.success,
      parameters: {
        'preparation_mode': _preparationModeWireValue(preparationMode),
        'preparation_step_count': preparationStepCount,
        'minutes_until_schedule': minutesUntilSchedule,
      },
    );
  }

  final String name;
  final String workflow;
  final String result;
  final int schemaVersion;
  final Map<String, Object> parameters;

  Map<String, Object> toAnalyticsParameters({
    required String platform,
    required String appVersion,
  }) {
    return {
      'schema_version': schemaVersion,
      'workflow': workflow,
      'result': result,
      'platform': platform,
      'app_version': appVersion,
      ...parameters,
    };
  }
}

enum ProductUsageResult {
  success('success'),
  failure('failure'),
  allowed('allowed'),
  denied('denied'),
  disabled('disabled');

  const ProductUsageResult(this.wireValue);

  final String wireValue;
}

enum ProductUsageWorkflow {
  analytics('analytics'),
  onboarding('onboarding'),
  authentication('authentication'),
  schedule('schedule'),
  notification('notification'),
  alarm('alarm');

  const ProductUsageWorkflow(this.wireValue);

  final String wireValue;
}

enum ProductUsageEventParameterKey {
  enabled('enabled'),
  source('source'),
  preparationStepCount('preparation_step_count'),
  spareTimeMinutes('spare_time_minutes'),
  authProvider('auth_provider'),
  preparationMode('preparation_mode'),
  minutesUntilSchedule('minutes_until_schedule'),
  preparationChanged('preparation_changed'),
  permissionResult('permission_result'),
  launchAction('launch_action'),
  provider('provider'),
  errorCode('error_code'),
  latenessBucket('lateness_bucket'),
  startedEarly('started_early');

  const ProductUsageEventParameterKey(this.wireValue);

  final String wireValue;

  static ProductUsageEventParameterKey? fromWireValue(String wireValue) {
    for (final key in ProductUsageEventParameterKey.values) {
      if (key.wireValue == wireValue) return key;
    }
    return null;
  }
}

class ProductUsageEventDefinition {
  const ProductUsageEventDefinition({
    required this.name,
    required this.workflow,
    required this.allowedParameters,
    this.schemaVersion = 1,
  });

  final String name;
  final ProductUsageWorkflow workflow;
  final Set<ProductUsageEventParameterKey> allowedParameters;
  final int schemaVersion;

  Set<String> get allowedParameterNames => Set.unmodifiable(
    allowedParameters.map((parameter) => parameter.wireValue),
  );
}

class ProductUsageEventCatalog {
  const ProductUsageEventCatalog._();

  static const analyticsPreferenceChanged = ProductUsageEventDefinition(
    name: 'analytics_preference_changed',
    workflow: ProductUsageWorkflow.analytics,
    allowedParameters: {
      ProductUsageEventParameterKey.enabled,
      ProductUsageEventParameterKey.source,
    },
  );

  static const onboardingCompleted = ProductUsageEventDefinition(
    name: 'onboarding_completed',
    workflow: ProductUsageWorkflow.onboarding,
    allowedParameters: {
      ProductUsageEventParameterKey.preparationStepCount,
      ProductUsageEventParameterKey.spareTimeMinutes,
    },
  );

  static const signUpCompleted = ProductUsageEventDefinition(
    name: 'sign_up_completed',
    workflow: ProductUsageWorkflow.authentication,
    allowedParameters: {ProductUsageEventParameterKey.authProvider},
  );

  static const loginCompleted = ProductUsageEventDefinition(
    name: 'login_completed',
    workflow: ProductUsageWorkflow.authentication,
    allowedParameters: {ProductUsageEventParameterKey.authProvider},
  );

  static const scheduleCreateStarted = ProductUsageEventDefinition(
    name: 'schedule_create_started',
    workflow: ProductUsageWorkflow.schedule,
    allowedParameters: {ProductUsageEventParameterKey.source},
  );

  static const scheduleCreated = ProductUsageEventDefinition(
    name: 'schedule_created',
    workflow: ProductUsageWorkflow.schedule,
    allowedParameters: {
      ProductUsageEventParameterKey.preparationMode,
      ProductUsageEventParameterKey.preparationStepCount,
      ProductUsageEventParameterKey.minutesUntilSchedule,
    },
  );

  static const scheduleUpdated = ProductUsageEventDefinition(
    name: 'schedule_updated',
    workflow: ProductUsageWorkflow.schedule,
    allowedParameters: {
      ProductUsageEventParameterKey.preparationChanged,
      ProductUsageEventParameterKey.minutesUntilSchedule,
    },
  );

  static const scheduleDeleted = ProductUsageEventDefinition(
    name: 'schedule_deleted',
    workflow: ProductUsageWorkflow.schedule,
    allowedParameters: {ProductUsageEventParameterKey.minutesUntilSchedule},
  );

  static const notificationPermissionResult = ProductUsageEventDefinition(
    name: 'notification_permission_result',
    workflow: ProductUsageWorkflow.notification,
    allowedParameters: {
      ProductUsageEventParameterKey.permissionResult,
      ProductUsageEventParameterKey.source,
    },
  );

  static const alarmOpened = ProductUsageEventDefinition(
    name: 'alarm_opened',
    workflow: ProductUsageWorkflow.alarm,
    allowedParameters: {
      ProductUsageEventParameterKey.launchAction,
      ProductUsageEventParameterKey.provider,
    },
  );

  static const alarmFailed = ProductUsageEventDefinition(
    name: 'alarm_failed',
    workflow: ProductUsageWorkflow.alarm,
    allowedParameters: {
      ProductUsageEventParameterKey.errorCode,
      ProductUsageEventParameterKey.provider,
    },
  );

  static const scheduleFinished = ProductUsageEventDefinition(
    name: 'schedule_finished',
    workflow: ProductUsageWorkflow.schedule,
    allowedParameters: {
      ProductUsageEventParameterKey.latenessBucket,
      ProductUsageEventParameterKey.preparationStepCount,
      ProductUsageEventParameterKey.startedEarly,
    },
  );

  static const firstReleaseEvents = <ProductUsageEventDefinition>[
    analyticsPreferenceChanged,
    onboardingCompleted,
    signUpCompleted,
    loginCompleted,
    scheduleCreateStarted,
    scheduleCreated,
    scheduleUpdated,
    scheduleDeleted,
    notificationPermissionResult,
    alarmOpened,
    alarmFailed,
    scheduleFinished,
  ];

  static final Map<String, ProductUsageEventDefinition> _definitionsByName = {
    for (final definition in firstReleaseEvents) definition.name: definition,
  };

  static const _forbiddenParameterNames = <String>{
    'email',
    'display_name',
    'oauth_identifier',
    'fcm_token',
    'access_token',
    'refresh_token',
    'schedule_name',
    'schedule_note',
    'place_name',
    'preparation_step_name',
    'exception',
    'stack_trace',
    'request_body',
    'response_body',
    'location',
    'latitude',
    'longitude',
  };

  static ProductUsageEventDefinition definitionFor(String name) {
    final definition = _definitionsByName[name];
    if (definition == null) {
      throw ProductUsageEventCatalogException(
        'Unknown Product Usage Event: $name',
      );
    }
    return definition;
  }

  static Map<String, Object> validateParameters(
    ProductUsageEventDefinition definition,
    Map<String, Object> parameters,
  ) {
    final validatedParameters = <String, Object>{};
    for (final entry in parameters.entries) {
      final key = entry.key;
      final value = entry.value;
      if (_forbiddenParameterNames.contains(key)) {
        throw ProductUsageEventCatalogException(
          'Forbidden Analytics Event Parameter: $key',
        );
      }

      final parameterKey = ProductUsageEventParameterKey.fromWireValue(key);
      if (parameterKey == null ||
          !definition.allowedParameters.contains(parameterKey)) {
        throw ProductUsageEventCatalogException(
          'Parameter $key is not allowed for ${definition.name}',
        );
      }

      _validateParameterValue(key, value);
      validatedParameters[key] = value;
    }
    return Map.unmodifiable(validatedParameters);
  }

  static void _validateParameterValue(String key, Object value) {
    if (value is Map || value is Iterable) {
      throw ProductUsageEventCatalogException(
        'Parameter $key must be a scalar analytics value',
      );
    }
    if (value is String || value is num || value is bool) return;
    throw ProductUsageEventCatalogException(
      'Parameter $key has unsupported value type ${value.runtimeType}',
    );
  }
}

class ProductUsageEventCatalogException implements Exception {
  const ProductUsageEventCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _preparationModeWireValue(SchedulePreparationMode? mode) {
  switch (mode) {
    case SchedulePreparationMode.template:
      return 'template';
    case SchedulePreparationMode.custom:
      return 'custom';
    case SchedulePreparationMode.defaultPreparation:
    case null:
      return 'default';
  }
}
