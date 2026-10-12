import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/update_controller.dart';
import 'package:leccheck/core/notifications/android_device.dart';
import 'package:leccheck/core/update/linux_self_update.dart';
import 'package:leccheck/core/update/update_download.dart';
import 'package:leccheck/core/update/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Map<String, Object?> _entry(String version, int build) => {
  'version': version,
  'build': build,
  'date': '2026-10-20',
  'notesUrl': 'https://example.com/releases/tag/v$version',
  'androidArm64': 'https://example.com/$version-android-arm64.apk',
  'androidUniversal': 'https://example.com/$version-android.apk',
  'linux': 'https://example.com/$version-linux-x64.tar.gz',
};

/// The release files the mock GitHub serves.
final _apk = List.generate(70000, (i) => i * 7 % 256);
final _tarball = List.generate(50000, (i) => i * 13 % 256);

/// [entry] with the hashes of the files above.
Map<String, Object?> _hashed(Map<String, Object?> entry) => {
  ...entry,
  'sha256': {
    'androidUniversal': sha256.convert(_apk).toString(),
    'linux': sha256.convert(_tarball).toString(),
  },
};

final _manifest = {
  'stable': _entry('2.0.0', 20),
  'beta': _entry('2.0.1-beta.1', 21),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pickUpdate', () {
    test('betas follow the beta channel, stable versions stable', () {
      expect(
        pickUpdate(
          _manifest,
          installedVersion: '2.0.0-beta.5',
          build: 13,
        )?.version,
        '2.0.1-beta.1',
      );
      expect(
        pickUpdate(_manifest, installedVersion: '2.0.0', build: 13)?.version,
        '2.0.0',
      );
    });

    test('nothing when the installed build is as new or newer', () {
      expect(
        pickUpdate(_manifest, installedVersion: '2.0.0', build: 20),
        isNull,
      );
      expect(
        pickUpdate(_manifest, installedVersion: '2.0.1-beta.1', build: 21),
        isNull,
      );
    });

    test('a broken or missing manifest offers nothing', () {
      for (final broken in [
        null,
        'text',
        <String, Object?>{},
        {'beta': 'x'},
        {
          'beta': {'version': '3.0.0'},
        },
      ]) {
        expect(
          pickUpdate(broken, installedVersion: '2.0.0-beta.5', build: 13),
          isNull,
        );
      }
    });
  });

  test('installedBuild undoes Android\'s per-ABI version codes', () {
    expect(installedBuild('2012'), 12); // arm64-v8a APK
    expect(installedBuild('1012'), 12); // armeabi-v7a
    expect(installedBuild('12'), 12); // universal APK, Linux
    expect(installedBuild(''), 0);
  });

  test('Download picks the APK for this phone', () {
    final update = AppUpdate.tryParse(_entry('2.0.0', 20))!;
    expect(
      update.downloadUrl(android: true, arm64: true),
      'https://example.com/2.0.0-android-arm64.apk',
    );
    expect(
      update.downloadUrl(android: true, arm64: false),
      'https://example.com/2.0.0-android.apk',
    );
    // Linux installs from the tarball with install.sh: the release page.
    expect(
      update.downloadUrl(android: false, arm64: false),
      'https://example.com/releases/tag/v2.0.0',
    );
  });

  test('entries with wrong types or links that aren\'t https are ignored', () {
    AppUpdate? parse(Map<String, Object?> changes) =>
        AppUpdate.tryParse({..._entry('2.0.0', 20), ...changes});
    expect(parse({'linux': 42}), isNull);
    expect(parse({'androidArm64': 'http://example.com/a.apk'}), isNull);
    expect(parse({'notesUrl': 'javascript:alert(1)'}), isNull);
    expect(parse({'androidUniversal': 'file:///sdcard/x.apk'}), isNull);
    // Optional links may be missing.
    expect(parse({'linux': null})!.linux, isNull);
  });

  test('hashes: only 64 hex digits count, and only hashed files install', () {
    final hash = 'AB' * 32;
    AppUpdate parse(Object? hashes) =>
        AppUpdate.tryParse({..._entry('2.0.0', 20), 'sha256': hashes})!;

    final update = parse({
      'androidArm64': hash,
      'androidUniversal': 'not a hash',
      'linux': 42,
    });
    expect(update.sha256, {'androidArm64': 'ab' * 32});
    expect(
      update.installFile(android: true, arm64: true),
      UpdateFile('https://example.com/2.0.0-android-arm64.apk', 'ab' * 32),
    );
    // No hash, no Update: Download opens the browser.
    expect(update.installFile(android: true, arm64: false), isNull);
    expect(update.installFile(android: false, arm64: false), isNull);
    expect(parse('x').sha256, isEmpty);
    expect(
      AppUpdate.tryParse(_entry('2.0.0', 20))!
          .installFile(android: true, arm64: true),
      isNull,
    );

    // Never the universal APK in place of the arm64 one (its version codes
    // are lower, so Android would refuse it).
    final universalOnly = parse({'androidUniversal': hash});
    expect(universalOnly.installFile(android: true, arm64: true), isNull);
    expect(
      universalOnly.installFile(android: true, arm64: false)?.url,
      'https://example.com/2.0.0-android.apk',
    );
  });

  group('downloadUpdate', () {
    late Directory dir;
    late File dest;
    final hash = sha256.convert(_apk).toString();

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('update_test');
      dest = File('${dir.path}/updates/update.apk');
    });
    tearDown(() => dir.delete(recursive: true));

    http.Client streaming(Stream<List<int>> body, {int status = 200}) =>
        MockClient.streaming(
          (_, _) async =>
              http.StreamedResponse(body, status, contentLength: _apk.length),
        );

    test('saves the verified file and reports progress', () async {
      final progress = <double>[];
      await downloadUpdate(
        streaming(
          Stream.fromIterable([_apk.sublist(0, 30000), _apk.sublist(30000)]),
        ),
        Uri.parse('https://example.com/a.apk'),
        hash.toUpperCase(),
        dest,
        onProgress: progress.add,
      );
      expect(await dest.readAsBytes(), _apk);
      expect(progress.first, closeTo(30000 / 70000, 1e-9));
      expect(progress.last, 1);
      expect(File('${dest.path}.part').existsSync(), isFalse);
    });

    test('a damaged, missing or broken-off download leaves nothing', () async {
      Future<void> download(http.Client client, {String url = 'https://x/a'}) =>
          downloadUpdate(client, Uri.parse(url), hash, dest);

      final damaged = [..._apk]..[100] ^= 1;
      await expectLater(
        download(streaming(Stream.value(damaged))),
        throwsA(isA<UpdateFailed>()),
      );
      await expectLater(
        download(streaming(Stream.value(_apk), status: 404)),
        throwsA(isA<UpdateFailed>()),
      );
      final brokenOff = StreamController<List<int>>()
        ..add(_apk.sublist(0, 1000))
        ..addError(http.ClientException('Connection closed'));
      await expectLater(
        download(streaming(brokenOff.stream)),
        throwsA(isA<UpdateFailed>()),
      );
      await expectLater(
        download(streaming(Stream.value(_apk)), url: 'http://x/a'),
        throwsA(isA<UpdateFailed>()),
      );
      expect(dest.existsSync(), isFalse);
      expect(File('${dest.path}.part').existsSync(), isFalse);
    });
  });

  group('LinuxSelfUpdate', () {
    late Directory dir;

    setUp(
      () async => dir = await Directory.systemTemp.createTemp('update_test'),
    );
    tearDown(() => dir.delete(recursive: true));

    /// A tarball like the release's, whose install.sh runs [script].
    Future<File> tarball(String script) async {
      final root = Directory('${dir.path}/src/LecCheck-9.9.9-linux-x64');
      await root.create(recursive: true);
      await File('${root.path}/install.sh').writeAsString(script);
      final tarball = File('${dir.path}/updates/update.tar.gz');
      await tarball.parent.create();
      final tar = await Process.run('tar', [
        '-czf',
        tarball.path,
        '-C',
        '${dir.path}/src',
        'LecCheck-9.9.9-linux-x64',
      ]);
      expect(tar.exitCode, 0, reason: '${tar.stderr}');
      return tarball;
    }

    test('runs the install.sh from the tarball, then cleans up', () async {
      final marker = '${dir.path}/installed';
      await LinuxSelfUpdate.install(await tarball('echo "\$0" > "$marker"'));
      expect(
        File(marker).readAsStringSync().trim(),
        endsWith('/extract/LecCheck-9.9.9-linux-x64/install.sh'),
      );
      expect(Directory('${dir.path}/updates/extract').existsSync(), isFalse);
    });

    test('a failing install.sh fails the update, with its output', () async {
      await expectLater(
        LinuxSelfUpdate.install(
          await tarball('echo "Missing system libraries" >&2; exit 1'),
        ),
        throwsA(
          isA<UpdateFailed>().having(
            (e) => e.message,
            'message',
            contains('Missing system libraries'),
          ),
        ),
      );
    });

    test('only an app install.sh installed updates itself', () async {
      // The test runner isn't ~/.local/share/leccheck/leccheck.
      expect(await LinuxSelfUpdate.installDir(), isNull);
    });
  }, skip: Platform.isLinux ? false : 'tar and bash: Linux only');

  group('UpdateController', () {
    late SharedPreferencesWithCache prefs;
    late int requests;
    late Object? served;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      );
      requests = 0;
      served = _manifest;
      UpdateController.client = () => MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('.apk')) return http.Response.bytes(_apk, 200);
        if (path.endsWith('.tar.gz')) return http.Response.bytes(_tarball, 200);
        requests++;
        return served is String
            ? http.Response(served! as String, 200)
            : http.Response(jsonEncode(served), 200);
      });
      PackageInfo.setMockInitialValues(
        appName: 'LecCheck',
        packageName: 'com.leccheck.app',
        version: '2.0.0-beta.5',
        buildNumber: '2013',
        buildSignature: '',
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      UpdateController.client = http.Client.new;
      UpdateController.directory = updatesDirectory;
      UpdateController.installApk = AndroidDevice.installApk;
      UpdateController.linuxInstallDir = LinuxSelfUpdate.installDir;
      UpdateController.installTarball = LinuxSelfUpdate.install;
    });

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    final morning = DateTime(2026, 10, 20, 9);

    test('offers a newer release and checks at most once a day', () async {
      final c = container();
      final controller = c.read(updateProvider.notifier);
      await controller.check(now: morning);
      expect(c.read(updateProvider).update?.version, '2.0.1-beta.1');
      // No hashes in the manifest: Download opens the browser.
      expect(c.read(updateProvider).file, isNull);
      expect(requests, 1);

      // Later the same day, and after a restart: from the saved answer.
      await controller.check(now: morning.add(const Duration(hours: 5)));
      final restarted = container();
      await restarted
          .read(updateProvider.notifier)
          .check(now: morning.add(const Duration(hours: 6)));
      expect(restarted.read(updateProvider).update?.version, '2.0.1-beta.1');
      expect(requests, 1);

      // The next day: asks again.
      await controller.check(now: morning.add(const Duration(days: 1)));
      expect(requests, 2);
    });

    test('"Skip this version" hides it until a newer one', () async {
      final c = container();
      final controller = c.read(updateProvider.notifier);
      await controller.check(now: morning);
      await controller.skip();
      expect(c.read(updateProvider).update, isNull);

      await controller.check(now: morning.add(const Duration(days: 1)));
      expect(c.read(updateProvider).update, isNull);

      served = {..._manifest, 'beta': _entry('2.0.1-beta.2', 22)};
      await controller.check(now: morning.add(const Duration(days: 2)));
      expect(c.read(updateProvider).update?.version, '2.0.1-beta.2');
    });

    test('"Later" keeps it in Settings only', () async {
      final c = container();
      final controller = c.read(updateProvider.notifier);
      await controller.check(now: morning);
      await controller.later();
      expect(c.read(updateProvider).later, isTrue);
      expect(c.read(updateProvider).update, isNotNull);

      final restarted = container();
      await restarted.read(updateProvider.notifier).check(now: morning);
      expect(restarted.read(updateProvider).later, isTrue);
    });

    test('a broken manifest or no network shows nothing', () async {
      served = 'not json';
      final c = container();
      await c.read(updateProvider.notifier).check(now: morning);
      expect(c.read(updateProvider).update, isNull);

      UpdateController.client = () =>
          MockClient((_) async => throw http.ClientException('offline'));
      await c.read(updateProvider.notifier).check(force: true);
      expect(c.read(updateProvider).update, isNull);
    });

    test('nothing while turned off, except Check now', () async {
      final c = container();
      final controller = c.read(updateProvider.notifier);
      await controller.setEnabled(false);
      await controller.check(now: morning);
      expect(requests, 0);
      expect(await controller.check(force: true), isNotNull);
    });

    test('Obtainium updates LecCheck by itself', () async {
      PackageInfo.setMockInitialValues(
        appName: 'LecCheck',
        packageName: 'com.leccheck.app',
        version: '2.0.0-beta.5',
        buildNumber: '2013',
        buildSignature: '',
        installerStore: 'dev.imranr.obtainium.fdroid',
      );
      final c = container();
      await c.read(updateProvider.notifier).check(now: morning);
      expect(requests, 0);
      expect(c.read(updateProvider).update, isNull);
    });

    test('iPhone updates come from AltStore', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final c = container();
      await c.read(updateProvider.notifier).check(force: true);
      expect(requests, 0);
    });

    group('Update', () {
      late Directory dir;

      setUp(() async {
        dir = await Directory.systemTemp.createTemp('update_test');
        UpdateController.directory = () async => Directory('${dir.path}/u');
        served = {'beta': _hashed(_entry('2.0.1-beta.1', 21))};
      });
      tearDown(() => dir.delete(recursive: true));

      test('Android: downloads the APK and opens the installer', () async {
        final opened = <String>[];
        UpdateController.installApk = (apk) async {
          opened.add(apk);
          return true;
        };
        final c = container();
        final controller = c.read(updateProvider.notifier);
        await controller.check(now: morning);
        expect(c.read(updateProvider).file?.url, endsWith('-android.apk'));

        await controller.install();
        final apk = '${dir.path}/u/update.apk';
        expect(c.read(updateProvider).phase, UpdatePhase.downloaded);
        expect(opened, [apk]);
        expect(await File(apk).readAsBytes(), _apk);

        // Back from the system dialog: the check keeps the phase, and
        // Install opens the same file again.
        await controller.check(force: true);
        expect(c.read(updateProvider).phase, UpdatePhase.downloaded);
        await controller.install();
        expect(opened, [apk, apk]);

        // Once installed (the app is up to date), the APK is deleted.
        PackageInfo.setMockInitialValues(
          appName: 'LecCheck',
          packageName: 'com.leccheck.app',
          version: '2.0.1-beta.1',
          buildNumber: '21',
          buildSignature: '',
        );
        await controller.check(force: true);
        expect(Directory('${dir.path}/u').existsSync(), isFalse);
      });

      test('a file that doesn\'t match its hash is never installed', () async {
        served = {
          'beta': {
            ..._entry('2.0.1-beta.1', 21),
            'sha256': {'androidUniversal': '0' * 64},
          },
        };
        var opened = false;
        UpdateController.installApk = (_) async => opened = true;
        final c = container();
        final controller = c.read(updateProvider.notifier);
        await controller.check(now: morning);
        await controller.install();
        expect(c.read(updateProvider).phase, UpdatePhase.failed);
        expect(opened, isFalse);
        expect(File('${dir.path}/u/update.apk').existsSync(), isFalse);
      });

      test('Cancel stops the download', () async {
        final body = StreamController<List<int>>();
        UpdateController.client = () =>
            MockClient.streaming((request, _) async {
              if (!request.url.path.endsWith('.apk')) {
                return http.StreamedResponse(
                  Stream.value(utf8.encode(jsonEncode(served))),
                  200,
                );
              }
              return http.StreamedResponse(
                body.stream,
                200,
                contentLength: _apk.length,
              );
            });
        final c = container();
        final controller = c.read(updateProvider.notifier);
        await controller.check(now: morning);
        // Waits for the first progress (writing the file takes real time).
        final progressed = Completer<void>();
        c.listen(updateProvider, (_, next) {
          if (next.progress != null && !progressed.isCompleted) {
            progressed.complete();
          }
        });
        final installing = controller.install();
        body.add(_apk.sublist(0, 7000));
        await progressed.future;
        expect(c.read(updateProvider).phase, UpdatePhase.downloading);
        expect(c.read(updateProvider).progress, closeTo(0.1, 1e-9));

        controller.cancel();
        expect(c.read(updateProvider).phase, UpdatePhase.idle);
        // Closing the client breaks the connection off.
        body.addError(http.ClientException('Connection closed'));
        await installing;
        expect(c.read(updateProvider).phase, UpdatePhase.idle);
        expect(File('${dir.path}/u/update.apk.part').existsSync(), isFalse);
      });

      test('Linux: installs the tarball, then Restart', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        PackageInfo.setMockInitialValues(
          appName: 'LecCheck',
          packageName: 'com.leccheck.app',
          version: '2.0.0-beta.5',
          buildNumber: '13',
          buildSignature: '',
        );
        UpdateController.linuxInstallDir = () async => '/fake/leccheck';
        final installed = <List<int>>[];
        UpdateController.installTarball = (tarball) async =>
            installed.add(await tarball.readAsBytes());
        final c = container();
        final controller = c.read(updateProvider.notifier);
        await controller.check(now: morning);
        expect(c.read(updateProvider).file?.url, endsWith('.tar.gz'));

        await controller.install();
        expect(c.read(updateProvider).phase, UpdatePhase.restart);
        expect(installed, [_tarball]);
        expect(Directory('${dir.path}/u').existsSync(), isFalse);
      });

      test(
        'Linux builds install.sh didn\'t install open the browser',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.linux;
          UpdateController.linuxInstallDir = () async => null;
          final c = container();
          await c.read(updateProvider.notifier).check(now: morning);
          expect(c.read(updateProvider).update, isNotNull);
          expect(c.read(updateProvider).file, isNull);
        },
      );
    });
  });
}
