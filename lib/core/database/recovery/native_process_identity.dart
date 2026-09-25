import 'package:flutter/services.dart';
import 'store_pair.dart';

Future<String> readNativeProcessIdentity() async {
  final value = await const MethodChannel(
    'on_time_front/native_alarm',
  ).invokeMethod<String>('getProcessIdentity');
  if (value == null || !StorePair.isCandidateId(value)) {
    throw const PairAuthorityUnavailable();
  }
  return value;
}
