import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:on_time_front/core/services/device_info_service/shared.dart';

/// Keeps OS document UI separate from backup encryption and persistence.
class BackupFilePicker {
  BackupFilePicker({bool? isIOS})
    : _isIOS = isIOS ?? DeviceInfoService.osType == OsType.ios;

  static const _channel = MethodChannel('on_time_front/backup_files');
  static const typeGroup = XTypeGroup(
    label: 'OnTime Backup',
    extensions: ['ontimebackup'],
    mimeTypes: ['application/octet-stream'],
    // iOS requires UTIs. Authentication, rather than the file extension,
    // determines whether the selected file is a valid OnTime backup.
    uniformTypeIdentifiers: ['public.data'],
  );

  final bool _isIOS;

  Future<bool> save(Uint8List encrypted, String suggestedName) async {
    if (_isIOS) {
      return await _channel.invokeMethod<bool>('exportBackup', {
            'bytes': encrypted,
            'suggestedName': suggestedName,
          }) ??
          false;
    }
    final location = await getSaveLocation(
      acceptedTypeGroups: const [typeGroup],
      suggestedName: suggestedName,
    );
    if (location == null) return false;
    await XFile.fromData(
      encrypted,
      name: suggestedName,
      mimeType: 'application/octet-stream',
    ).saveTo(location.path);
    return true;
  }

  Future<Uint8List?> select() async {
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    return file?.readAsBytes();
  }
}
