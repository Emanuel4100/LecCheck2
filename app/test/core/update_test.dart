import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:leccheck/app/providers.dart';
import 'package:leccheck/app/update_controller.dart';
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

final _manifest = {
  'stable': _entry('2.0.0', 20),
  'beta': _entry('2.0.1-beta.1', 21),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pickUpdate', () {
    test('betas follow the beta channel, stable versions stable', () {
      expect(
        pickUpdate(_manifest, installedVersion: '2.0.0-beta.5', build: 13)
            ?.version,
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
      UpdateController.client = () => MockClient((_) async {
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
  });
}
