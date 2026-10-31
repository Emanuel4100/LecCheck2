import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/update_controller.dart';
import 'package:leccheck/core/notifications/android_device.dart';
import 'package:leccheck/core/update/flatpak.dart';
import 'package:leccheck/core/update/tarball_install.dart';
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

/// A throwaway key standing in for the release workflow's.
late SimpleKeyPair _keys;

Future<String> _sign(String text) async => base64.encode(
  (await Ed25519().sign(utf8.encode(text), keyPair: _keys)).bytes,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final realKey = updatePublicKey;
  setUpAll(() async {
    _keys = await Ed25519().newKeyPair();
    updatePublicKey = base64.encode((await _keys.extractPublicKey()).bytes);
  });
  tearDownAll(() => updatePublicKey = realKey);

  group('signed manifest', () {
    test('accepts what the release workflow (OpenSSL) signs', () async {
      // fixtures/update.json: made by scripts/update_manifest.py, signed with
      // `openssl pkeyutl -sign -rawin` and a test key (public half below).
      final text = File('test/core/fixtures/update.json').readAsStringSync();
      final signature = File('test/core/fixtures/update.json.sig')
          .readAsStringSync();
      updatePublicKey = 'iWVsuoMHU5Piz3qMQM83Jk9r1/zv2PO+/0fgV5Ugoa8=';
      addTearDown(
        () async => updatePublicKey = base64.encode(
          (await _keys.extractPublicKey()).bytes,
        ),
      );
      final manifest = await SignedManifest(text, signature).verified();
      final update = pickUpdate(
        manifest,
        installedVersion: '2.0.0-beta.9',
        build: 29,
      );
      expect(update?.version, '2.0.0-beta.10');
      // The changelog section, for the update window.
      expect(update?.notes, startsWith('- **A roomier course editor**.'));

      // One changed character, and nothing is offered.
      final tampered = text.replaceFirst('"build": 30', '"build": 31');
      expect(await SignedManifest(tampered, signature).verified(), isNull);
      expect(await SignedManifest(text, 'not base64!').verified(), isNull);
    });

    test('signed by another key: refused', () async {
      final other = await Ed25519().newKeyPair();
      const text = '{"beta": {}}';
      final signature = base64.encode(
        (await Ed25519().sign(utf8.encode(text), keyPair: other)).bytes,
      );
      expect(await SignedManifest(text, signature).verified(), isNull);
      expect(await SignedManifest(text, await _sign(text)).verified(), {
        'beta': <String, Object?>{},
      });
    });
  });

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

  test('sizes and the Flatpak: only what parses counts', () {
    final update = AppUpdate.tryParse({
      ..._entry('2.0.0', 20),
      'sha256': {'androidUniversal': 'ab' * 32},
      'size': {'androidUniversal': 31200000, 'linux': -1, 'androidArm64': '9'},
      'flatpakref': 'https://example.com/leccheck.flatpakref',
    })!;
    expect(update.size, {'androidUniversal': 31200000});
    expect(update.installFile(android: true, arm64: false)?.size, 31200000);
    expect(update.flatpak, isTrue);
    expect(AppUpdate.tryParse(_entry('2.0.0', 20))!.flatpak, isFalse);
    expect(
      AppUpdate.tryParse({
        ..._entry('2.0.0', 20),
        'flatpakref': 'http://example.com/x.flatpakref',
      })!.flatpak,
      isFalse,
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

    test('saves the file and reports progress; verify names it', () async {
      final progress = <(int, int?)>[];
      await downloadUpdate(
        streaming(
          Stream.fromIterable([_apk.sublist(0, 30000), _apk.sublist(30000)]),
        ),
        Uri.parse('https://example.com/a.apk'),
        dest,
        onProgress: (received, total) => progress.add((received, total)),
      );
      expect(progress, [(30000, 70000), (70000, 70000)]);
      // Not yet the update: it hasn't been checked.
      expect(dest.existsSync(), isFalse);
      expect(await partOf(dest).readAsBytes(), _apk);

      final checked = <int>[];
      await verifyUpdate(dest, hash.toUpperCase(), onProgress: checked.add);
      expect(await dest.readAsBytes(), _apk);
      expect(checked.last, _apk.length);
      expect(partOf(dest).existsSync(), isFalse);
    });

    test('a damaged, missing or broken-off download leaves nothing', () async {
      Future<void> download(http.Client client, {String url = 'https://x/a'}) =>
          downloadUpdate(client, Uri.parse(url), dest);

      final damaged = [..._apk]..[100] ^= 1;
      await download(streaming(Stream.value(damaged)));
      await expectLater(
        verifyUpdate(dest, hash),
        throwsA(
          isA<UpdateNotVerified>().having(
            (e) => e.failure,
            'failure',
            UpdateFailure.notVerified,
          ),
        ),
      );
      await expectLater(
        download(streaming(Stream.value(_apk), status: 404)),
        throwsA(
          isA<UpdateFailed>().having(
            (e) => e.failure,
            'failure',
            UpdateFailure.notFound,
          ),
        ),
      );
      final brokenOff = StreamController<List<int>>()
        ..add(_apk.sublist(0, 1000))
        ..addError(http.ClientException('Connection closed'));
      await expectLater(
        download(streaming(brokenOff.stream)),
        throwsA(
          isA<UpdateFailed>().having(
            (e) => e.failure,
            'failure',
            UpdateFailure.network,
          ),
        ),
      );
      // Ended early without an error: fewer bytes than the server said.
      await expectLater(
        download(streaming(Stream.value(_apk.sublist(0, 500)))),
        throwsA(isA<UpdateFailed>()),
      );
      await expectLater(
        download(streaming(Stream.value(_apk)), url: 'http://x/a'),
        throwsA(isA<UpdateFailed>()),
      );
      expect(dest.existsSync(), isFalse);
      expect(partOf(dest).existsSync(), isFalse);
    });
  });

  group('TarballInstall', () {
    late Directory dir;

    setUp(
      () async => dir = await Directory.systemTemp.createTemp('update_test'),
    );
    tearDown(() => dir.delete(recursive: true));

    test('only an app install.sh installed moves', () async {
      // The test runner isn't ~/.local/share/leccheck/leccheck.
      expect(await TarballInstall.installDir(), isNull);
    });

    test('uninstall removes the app, never its data', () async {
      final home = dir.path;
      final data = '$home/.local/share';
      final app = '$data/leccheck';
      Future<File> file(String path) async =>
          File(path)..createSync(recursive: true);
      await file('$app/leccheck');
      await file('$app/lib/libapp.so');
      await file('$data/applications/com.leccheck.app.desktop');
      await file('$data/metainfo/com.leccheck.app.metainfo.xml');
      await file('$data/icons/hicolor/64x64/apps/com.leccheck.app.png');
      await file('$data/com.leccheck.app/leccheck.sqlite');
      await Directory('$home/.local/bin').create(recursive: true);
      await Link('$home/.local/bin/leccheck').create('$app/leccheck');
      // Someone else's leccheck command stays.
      await file('$home/elsewhere/leccheck');

      await TarballInstall.uninstall(app, dataHome: data, home: home);
      expect(Directory(app).existsSync(), isFalse);
      expect(Link('$home/.local/bin/leccheck').existsSync(), isFalse);
      expect(
        File('$data/applications/com.leccheck.app.desktop').existsSync(),
        isFalse,
      );
      expect(
        File('$data/icons/hicolor/64x64/apps/com.leccheck.app.png')
            .existsSync(),
        isFalse,
      );
      expect(
        File('$data/com.leccheck.app/leccheck.sqlite').existsSync(),
        isTrue,
      );

      // A link to another install isn't install.sh's: kept.
      await Link('$home/.local/bin/leccheck')
          .create('$home/elsewhere/leccheck');
      await TarballInstall.uninstall(app, dataHome: data, home: home);
      expect(Link('$home/.local/bin/leccheck').existsSync(), isTrue);
    });
  }, skip: Platform.isLinux ? false : 'Linux only');

  group('UpdateController', () {
    final realExit = UpdateController.exitApp;
    late SharedPreferencesWithCache prefs;
    late int requests;
    late Object? served;

    /// update.json (counted in [requests]) or its signature.
    Future<http.Response> manifestResponse(Uri url) async {
      final text = served is String ? served! as String : jsonEncode(served);
      if (url.path.endsWith('.sig')) {
        return http.Response(await _sign(text), 200);
      }
      requests++;
      return http.Response(text, 200);
    }

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
        return manifestResponse(request.url);
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
      UpdateController.linuxInstallDir = TarballInstall.installDir;
      UpdateController.isFlatpak = () => Flatpak.running;
      UpdateController.flatpakUpdate = FlatpakPortal.update;
      UpdateController.startLatestFlatpak = FlatpakPortal.startLatest;
      UpdateController.verifyAtLeast = const Duration(milliseconds: 900);
      UpdateController.exitApp = realExit;
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

    test('every start asks, even when asked today', () async {
      final c = container();
      final controller = c.read(updateProvider.notifier);
      await controller.check(now: morning);
      expect(requests, 1);
      await controller.check(
        startup: true,
        now: morning.add(const Duration(minutes: 5)),
      );
      expect(requests, 2);
    });

    test('only a manifest with a matching signature counts', () async {
      UpdateController.client = () => MockClient((request) async {
        if (request.url.path.endsWith('.sig')) {
          return http.Response(await _sign('something else'), 200);
        }
        requests++;
        return http.Response(jsonEncode(_manifest), 200);
      });
      final c = container();
      expect(await c.read(updateProvider.notifier).check(now: morning), isNull);
      expect(c.read(updateProvider).update, isNull);
    });

    test('a manifest kept by an older version is checked again', () async {
      // 2.0.0-beta.10 kept the manifest without a signature.
      await prefs.setString('update.manifest', jsonEncode(_manifest));
      await prefs.setInt('update.checkedAt', morning.millisecondsSinceEpoch);
      final c = container();
      await c.read(updateProvider.notifier).check(now: morning);
      expect(requests, 1, reason: 'fetched, though checked today');
      expect(c.read(updateProvider).update?.version, '2.0.1-beta.1');
    });

    test('the update window opens by itself once per launch', () async {
      final c = container();
      final controller = c.read(updateProvider.notifier);
      expect(controller.takePrompt(), isFalse, reason: 'nothing found yet');
      await controller.check(now: morning);
      expect(controller.takePrompt(), isTrue);
      await controller.check(now: morning);
      expect(controller.takePrompt(), isFalse);

      // "Later" doesn't stop it on the next launch; "Skip" does.
      await controller.later();
      final next = container().read(updateProvider.notifier);
      await next.check(now: morning);
      expect(next.takePrompt(), isTrue);
      await next.skip();
      final after = container().read(updateProvider.notifier);
      await after.check(now: morning);
      expect(after.takePrompt(), isFalse);
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
        UpdateController.verifyAtLeast = Duration.zero;
        served = {'beta': _hashed(_entry('2.0.1-beta.1', 21))};
      });
      tearDown(() => dir.delete(recursive: true));

      test(
        'Android: downloads the APK, checks it, opens the installer',
        () async {
          final opened = <String>[];
          UpdateController.installApk = (apk) async {
            opened.add(apk);
            return true;
          };
          final c = container();
          final controller = c.read(updateProvider.notifier);
          await controller.check(now: morning);
          expect(c.read(updateProvider).via, UpdateVia.apk);
          expect(c.read(updateProvider).file?.url, endsWith('-android.apk'));

          final phases = <UpdatePhase>[];
          c.listen(updateProvider, (_, next) {
            if (phases.lastOrNull != next.phase) phases.add(next.phase);
          });
          await controller.install();
          expect(phases, [
            UpdatePhase.downloading,
            UpdatePhase.verifying,
            UpdatePhase.downloaded,
          ]);
          expect(c.read(updateProvider).checkProgress, 1);
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
        },
      );

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
        expect(c.read(updateProvider).failedStep, UpdateStep.verify);
        expect(c.read(updateProvider).failure, UpdateFailure.notVerified);
        expect(opened, isFalse);
        expect(File('${dir.path}/u/update.apk').existsSync(), isFalse);
      });

      test('Cancel stops the download', () async {
        final body = StreamController<List<int>>();
        UpdateController.client = () => MockClient.streaming((
          request,
          _,
        ) async {
          if (!request.url.path.endsWith('.apk')) {
            final response = await manifestResponse(request.url);
            return http.StreamedResponse(Stream.value(response.bodyBytes), 200);
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

      test('Linux installs made by install.sh move to the Flatpak', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        UpdateController.linuxInstallDir = () async => '/fake/leccheck';
        final c = container();
        await c.read(updateProvider.notifier).check(now: morning);
        expect(c.read(updateProvider).via, UpdateVia.move);
        // Update does nothing itself: the move window takes over.
        await c.read(updateProvider.notifier).install();
        expect(c.read(updateProvider).phase, UpdatePhase.idle);
      });

      test('other Linux builds open the browser', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        UpdateController.linuxInstallDir = () async => null;
        final c = container();
        await c.read(updateProvider.notifier).check(now: morning);
        expect(c.read(updateProvider).update, isNotNull);
        expect(c.read(updateProvider).via, UpdateVia.browser);
        expect(c.read(updateProvider).file, isNull);
      });

      group('Flatpak', () {
        late StreamController<FlatpakProgress> portal;
        var restarted = 0;
        var exited = 0;

        setUp(() {
          debugDefaultTargetPlatformOverride = TargetPlatform.linux;
          PackageInfo.setMockInitialValues(
            appName: 'LecCheck',
            packageName: 'com.leccheck.app',
            version: '2.0.0-beta.15',
            buildNumber: '23',
            buildSignature: '',
          );
          served = {
            'beta': {
              ..._entry('2.0.0-beta.16', 24),
              'flatpakref': 'https://example.com/leccheck.flatpakref',
            },
          };
          UpdateController.isFlatpak = () => true;
          portal = StreamController();
          UpdateController.flatpakUpdate = () => portal.stream;
          restarted = 0;
          exited = 0;
          UpdateController.startLatestFlatpak = () async => restarted++;
          UpdateController.exitApp = () async => exited++;
        });

        Future<ProviderContainer> checked() async {
          final c = container();
          await c.read(updateProvider.notifier).check(now: morning);
          expect(c.read(updateProvider).via, UpdateVia.flatpak);
          return c;
        }

        test('the portal installs it, then Restart', () async {
          final c = await checked();
          final controller = c.read(updateProvider.notifier);
          final installing = controller.install();
          expect(c.read(updateProvider).phase, UpdatePhase.downloading);
          portal.add(const FlatpakProgress(FlatpakStatus.running, ops: 2));
          portal.add(
            const FlatpakProgress(
              FlatpakStatus.running,
              op: 1,
              ops: 2,
              percent: 50,
            ),
          );
          await pumpEventQueue();
          expect(c.read(updateProvider).progress, 0.75);
          portal.add(
            const FlatpakProgress(
              FlatpakStatus.done,
              op: 1,
              ops: 2,
              percent: 100,
            ),
          );
          await portal.close();
          await installing;
          expect(c.read(updateProvider).phase, UpdatePhase.restart);

          await controller.restart();
          expect(restarted, 1);
          expect(exited, 1);
        });

        test('each way it can fail says why', () async {
          final c = await checked();
          final controller = c.read(updateProvider.notifier);
          Future<UpdateState> ending(FlatpakProgress last) async {
            portal = StreamController();
            final installing = controller.install();
            portal.add(last);
            await portal.close();
            await installing;
            return c.read(updateProvider);
          }

          expect(
            (await ending(
              const FlatpakProgress(
                FlatpakStatus.failed,
                error: 'org.freedesktop.DBus.Error.AccessDenied',
                message: 'Application update not allowed',
              ),
            )).failure,
            UpdateFailure.flatpakDenied,
          );
          expect(
            (await ending(
              const FlatpakProgress(
                FlatpakStatus.failed,
                error: 'org.freedesktop.DBus.Error.NotSupported',
              ),
            )).failure,
            UpdateFailure.flatpakPermissions,
          );
          expect(
            (await ending(const FlatpakProgress(FlatpakStatus.empty))).failure,
            UpdateFailure.flatpakNotYet,
          );
          final other = await ending(
            const FlatpakProgress(
              FlatpakStatus.failed,
              error: 'org.freedesktop.Flatpak.Error.RemoteNotFound',
              message: 'No remote leccheck',
            ),
          );
          expect(other.failure, UpdateFailure.flatpak);
          expect(other.error, 'No remote leccheck');
          expect(other.phase, UpdatePhase.failed);

          // The portal isn't there at all.
          portal = StreamController();
          final installing = controller.install();
          portal.addError(
            Exception('org.freedesktop.DBus.Error.ServiceUnknown'),
          );
          await installing;
          expect(c.read(updateProvider).failure, UpdateFailure.flatpak);
        });

        test('Cancel closes the portal\'s update', () async {
          var cancelled = false;
          portal = StreamController(onCancel: () => cancelled = true);
          final c = await checked();
          final controller = c.read(updateProvider.notifier);
          final installing = controller.install();
          portal.add(const FlatpakProgress(FlatpakStatus.running, ops: 1));
          await pumpEventQueue();
          controller.cancel();
          await installing;
          expect(cancelled, isTrue);
          expect(c.read(updateProvider).phase, UpdatePhase.idle);
        });

        test('a release without a Flatpak opens the browser', () async {
          served = {'beta': _entry('2.0.0-beta.16', 24)};
          final c = container();
          await c.read(updateProvider.notifier).check(now: morning);
          expect(c.read(updateProvider).via, UpdateVia.browser);
        });

        test('a Restart that fails says so; the update stays', () async {
          UpdateController.startLatestFlatpak = () async =>
              throw Exception('No portal');
          final c = await checked();
          final controller = c.read(updateProvider.notifier);
          final installing = controller.install();
          portal.add(const FlatpakProgress(FlatpakStatus.done));
          await portal.close();
          await installing;
          await controller.restart();
          expect(exited, 0);
          expect(c.read(updateProvider).phase, UpdatePhase.restart);
          expect(c.read(updateProvider).failure, UpdateFailure.restart);
        });
      });
    });
  });
}
