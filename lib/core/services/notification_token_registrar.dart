abstract interface class FcmTokenRegistrar {
  Future<void> registerToken(String firebaseToken);
}

class NoopFcmTokenRegistrar implements FcmTokenRegistrar {
  const NoopFcmTokenRegistrar();

  @override
  Future<void> registerToken(String firebaseToken) async {}
}
