import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/services/app_metadata_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('package info metadata provider returns runtime app metadata', () async {
    PackageInfo.setMockInitialValues(
      appName: 'OnTime',
      packageName: 'devkor.ontime',
      version: '9.8.7',
      buildNumber: '654',
      buildSignature: '',
    );

    final metadata = await PackageInfoAppMetadataProvider().getMetadata();

    expect(metadata.version, '9.8.7');
    expect(metadata.buildNumber, '654');
  });
}
