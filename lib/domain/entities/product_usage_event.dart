class ProductUsageEvent {
  const ProductUsageEvent({
    required this.name,
    required this.workflow,
    required this.result,
    this.parameters = const {},
  });

  final String name;
  final String workflow;
  final String result;
  final Map<String, Object> parameters;

  Map<String, Object> toAnalyticsParameters({
    required String platform,
    required String appVersion,
  }) {
    return {
      'schema_version': 1,
      'workflow': workflow,
      'result': result,
      'platform': platform,
      'app_version': appVersion,
      ...parameters,
    };
  }
}
