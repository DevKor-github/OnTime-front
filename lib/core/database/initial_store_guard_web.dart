import 'installation_key_store.dart';

final class InitialStoreGuard {
  static Future<InitialStoreGuard> device(InstallationKeyStore keys) async =>
      InitialStoreGuard();
  Future<void> requireNoLocalEvidence() async {}
  Future<void> completeVerifiedCreation() async {}
  static Future<void> removeDeviceReceipt() async {}
}
