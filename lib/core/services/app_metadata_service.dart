import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppMetadata {
  const AppMetadata({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;
}

abstract interface class AppMetadataProvider {
  Future<AppMetadata> getMetadata();
}

@Singleton(as: AppMetadataProvider)
class PackageInfoAppMetadataProvider implements AppMetadataProvider {
  @override
  Future<AppMetadata> getMetadata() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return AppMetadata(
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
    );
  }
}
