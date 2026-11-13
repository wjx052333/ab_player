import 'package:flutter_test/flutter_test.dart';
import 'package:audacity_player/services/storage_permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StoragePermissionService Tests', () {
    test('isStoragePermissionGranted returns true on non-Android platform in tests', () async {
      final granted = await StoragePermissionService.isStoragePermissionGranted();
      expect(granted, isTrue);
    });

    test('getSearchDirectories returns valid non-empty list on desktop test', () async {
      final dirs = await StoragePermissionService.getSearchDirectories();
      expect(dirs, isA<List<String>>());
    });
  });
}
