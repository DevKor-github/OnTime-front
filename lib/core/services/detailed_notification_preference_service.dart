import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';

@lazySingleton
class DetailedNotificationPreferenceService {
  DetailedNotificationPreferenceService(this._database);

  final AppDatabase _database;

  Future<bool> getEnabled() async {
    final settings = await _database.userDao.getAlarmSettings(localProfileId);
    return settings.detailedNotificationContent;
  }

  Future<void> setEnabled(bool enabled) {
    return _database.userDao.updateDetailedNotificationContent(
      userId: localProfileId,
      enabled: enabled,
    );
  }
}
