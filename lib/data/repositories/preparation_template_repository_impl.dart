import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/constants/local_profile.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/data/daos/preparation_template_dao.dart';
import 'package:on_time_front/data/daos/user_dao.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_template_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_template_repository.dart';

@Singleton(as: PreparationTemplateRepository)
class PreparationTemplateRepositoryImpl
    implements PreparationTemplateRepository {
  PreparationTemplateRepositoryImpl(AppDatabase database)
    : _dao = database.preparationTemplateDao,
      _userDao = database.userDao;

  final PreparationTemplateDao _dao;
  final UserDao _userDao;

  @override
  Future<List<PreparationTemplateEntity>> getPreparationTemplates() =>
      _dao.getAll();

  @override
  Future<PreparationTemplateEntity> getPreparationTemplate(String templateId) =>
      _dao.getById(templateId);

  @override
  Future<void> createPreparationTemplate({
    required String templateId,
    required String templateName,
    required PreparationEntity preparation,
  }) async {
    await _dao.put(
      id: templateId,
      name: templateName,
      preparation: preparation,
      now: DateTime.now(),
    );
    await _userDao.markDurableDataChanged(localProfileId);
  }

  @override
  Future<void> updatePreparationTemplate({
    required String templateId,
    required String templateName,
    required PreparationEntity preparation,
  }) => createPreparationTemplate(
    templateId: templateId,
    templateName: templateName,
    preparation: preparation,
  );

  @override
  Future<void> deletePreparationTemplate(String templateId) async {
    await _dao.deleteById(templateId);
    await _userDao.markDurableDataChanged(localProfileId);
  }
}
