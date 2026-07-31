import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_note/services/storage_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // path_provider has no native implementation in unit tests, so point its
  // MethodChannel at a throwaway temp directory.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return Directory.systemTemp.createTempSync('fn_test').path;
          }
          return null;
        },
      );

  group('App update download directory', () {
    test(
      'appDataDir points at the free_note data dir (not the repo)',
      () async {
        final dir = await StorageService.instance.appDataDir;
        expect(dir.path, endsWith('free_note'));
      },
    );

    test(
      'download folder lives under appDataDir and is cleared on launch',
      () async {
        final base = await StorageService.instance.appDataDir;
        final dl = Directory(p.join(base.path, 'download'));
        // Seed the folder with a stale APK and a nested subfolder.
        dl.createSync(recursive: true);
        File(p.join(dl.path, 'free-note-1.0.0.apk')).writeAsStringSync('apk');
        Directory(p.join(dl.path, 'nested')).createSync();
        File(p.join(dl.path, 'nested', 'old.apk')).writeAsStringSync('x');
        expect(dl.listSync().length, 2);

        // Simulate the per-launch cleanup.
        await StorageService.instance.clearDownloadFolder();

        // Folder preserved, contents gone.
        expect(dl.existsSync(), isTrue);
        expect(dl.listSync(), isEmpty);
      },
    );

    test(
      'clearDownloadFolder is safe when the folder does not exist',
      () async {
        final base = await StorageService.instance.appDataDir;
        final dl = Directory(p.join(base.path, 'download'));
        if (dl.existsSync()) dl.deleteSync(recursive: true);
        // Must not throw.
        await StorageService.instance.clearDownloadFolder();
      },
    );
  });
}
