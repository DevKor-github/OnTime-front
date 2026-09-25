import 'package:on_time_front/domain/entities/default_preferences.dart';

abstract interface class DefaultPreferencesRepository {
  Future<DefaultPreferencesSnapshot> read();
  Future<DefaultPreferencesSaveReceipt> save(
    DefaultPreferencesSubmission input,
  );
  Future<DefaultPreferencesAuthority> authority(
    DefaultPreferencesSaveReceipt receipt,
  );
  int get generation;
  bool isGenerationCurrent(int generation);
}
