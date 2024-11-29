import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_time_front/core/dio/app_dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'riverpod.g.dart';

@riverpod
Dio dio(Ref ref) {
  var dio = AppDio();

  return dio;
}
