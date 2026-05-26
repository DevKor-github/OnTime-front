import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/endpoint.dart';
import 'package:on_time_front/domain/entities/analytics_preference.dart';

abstract interface class AnalyticsPreferenceRemoteDataSource {
  Future<AnalyticsPreference> getAnalyticsPreference();

  Future<AnalyticsPreference> updateAnalyticsPreference({
    required bool enabled,
  });
}

@Injectable(as: AnalyticsPreferenceRemoteDataSource)
class AnalyticsPreferenceRemoteDataSourceImpl
    implements AnalyticsPreferenceRemoteDataSource {
  AnalyticsPreferenceRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<AnalyticsPreference> getAnalyticsPreference() async {
    final result = await dio.get(Endpoint.analyticsPreference);
    if (result.statusCode == 200) {
      return _preferenceFromResponse(result.data);
    }
    throw Exception('Error getting analytics preference');
  }

  @override
  Future<AnalyticsPreference> updateAnalyticsPreference({
    required bool enabled,
  }) async {
    final result = await dio.put(
      Endpoint.analyticsPreference,
      data: {'enabled': enabled},
    );
    if (result.statusCode == 200) {
      return _preferenceFromResponse(result.data);
    }
    throw Exception('Error updating analytics preference');
  }

  AnalyticsPreference _preferenceFromResponse(Object? data) {
    final envelope = data as Map<String, dynamic>;
    final payload = envelope['data'] as Map<String, dynamic>;
    return AnalyticsPreference(
      enabled: payload['enabled'] as bool,
      updatedAt: DateTime.parse(payload['updatedAt'] as String),
    );
  }
}
