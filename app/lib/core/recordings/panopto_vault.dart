import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/session.dart';
import '../sync/sync_config.dart';
import 'panopto_api.dart';

/// The key that opens the account's Panopto vault: made by the device that
/// set Panopto up, and handed to others by pairing. Never leaves a device
/// unencrypted, and the server never sees it.
class VaultKey {
  const VaultKey({required this.userId, required this.bytes});

  factory VaultKey.random(String userId) {
    final random = Random.secure();
    return VaultKey(
      userId: userId,
      bytes: Uint8List.fromList(List.generate(32, (_) => random.nextInt(256))),
    );
  }

  factory VaultKey.fromJson(Map<String, Object?> json) => VaultKey(
    userId: json['userId']! as String,
    bytes: base64Url.decode(json['key']! as String),
  );

  /// The account it belongs to: a key is never used for another one.
  final String userId;
  final Uint8List bytes;

  /// Names the key without revealing it: the first 8 bytes of its SHA-256.
  String get kid => kidOf(bytes);

  static String kidOf(List<int> bytes) => sha256
      .convert(bytes)
      .bytes
      .take(8)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  Map<String, Object?> toJson() => {
    'userId': userId,
    'key': base64Url.encode(bytes),
  };
}

/// The vault as the server keeps it: ciphertext, and what it may know.
class VaultBox {
  const VaultBox({
    required this.v,
    required this.kid,
    required this.nonce,
    required this.ct,
    this.device = '',
    this.updatedAt = 0,
    this.lookedAt = 0,
    this.refused = false,
  });

  factory VaultBox.fromJson(Map<String, Object?> json) => VaultBox(
    v: (json['v'] as num?)?.toInt() ?? 0,
    kid: json['kid'] as String? ?? '',
    nonce: json['nonce'] as String? ?? '',
    ct: json['ct'] as String? ?? '',
    device: json['device'] as String? ?? '',
    updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    lookedAt: (json['lookedAt'] as num?)?.toInt() ?? 0,
    refused: json['refused'] == true,
  );

  /// The server's version: a device can only replace the one it read.
  final int v;
  final String kid;
  final String nonce;
  final String ct;

  /// The device that last saved it.
  final String device;
  final int updatedAt;
  final int lookedAt;

  /// Panopto refused this version's sign-in.
  final bool refused;
}

/// Encrypts the vault's contents (the Panopto setup and sign-in) with
/// AES-256-GCM. The account's user id is authenticated with it, so a vault
/// can't be moved to another account.
class VaultCrypto {
  static final _aes = AesGcm.with256bits();

  static List<int> _aad(String userId) =>
      utf8.encode('leccheck-panopto-v1:$userId');

  static Future<({String nonce, String ct})> seal(
    VaultKey key,
    Map<String, Object?> contents,
  ) async {
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(contents)),
      secretKey: SecretKey(key.bytes),
      aad: _aad(key.userId),
    );
    return (
      nonce: base64Url.encode(box.nonce),
      ct: base64Url.encode([...box.cipherText, ...box.mac.bytes]),
    );
  }

  /// Throws [PanoptoException] `vault_unreadable` for another key or a
  /// changed ciphertext.
  static Future<Map<String, Object?>> open(VaultKey key, VaultBox box) async {
    try {
      final bytes = base64Url.decode(box.ct);
      final clear = await _aes.decrypt(
        SecretBox(
          bytes.sublist(0, bytes.length - 16),
          nonce: base64Url.decode(box.nonce),
          mac: Mac(bytes.sublist(bytes.length - 16)),
        ),
        secretKey: SecretKey(key.bytes),
        aad: _aad(key.userId),
      );
      return (jsonDecode(utf8.decode(clear)) as Map).cast<String, Object?>();
    } on Object catch (e) {
      throw PanoptoException('vault_unreadable', '$e');
    }
  }
}

/// What `GET /v1/panopto/vault` says.
class VaultRead {
  const VaultRead({this.vault, this.pairs = const [], this.now = 0});

  final VaultBox? vault;
  final List<Map<String, Object?>> pairs;

  /// The server's time.
  final int now;
}

/// The device's name for others to see ("set up on …", pairing).
String thisDeviceName() {
  if (kIsWeb) return 'Web';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iPhone';
  final host = Platform.localHostname;
  final os = Platform.isLinux
      ? 'Linux'
      : Platform.isWindows
      ? 'Windows'
      : 'macOS';
  return host.isEmpty || host == 'localhost' ? os : '$os · $host';
}

/// The account's Panopto vault and pairing requests on the sync server.
///
/// Errors are [PanoptoException]s: `network` (no answer, the server busy,
/// or this device signed out), `conflict` (with [VaultConflict.vault]),
/// `busy` (another device holds the lease).
class VaultClient {
  VaultClient({required this.session, http.Client? client, this._base})
    : _http = client ?? http.Client();

  /// The signed-in account, or null.
  final Future<Session?> Function() session;
  final http.Client _http;
  final Uri? _base;

  Uri _url(String path) {
    final base = _base;
    return base == null
        ? SyncConfig.api('/v1/panopto$path')
        : base.resolve('/v1/panopto$path');
  }

  Future<(int, Map<String, Object?>)> _call(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final s = await session();
    if (s == null) throw const PanoptoException('network', 'signed out');
    final request = http.Request(method, _url(path))
      ..headers['Authorization'] = 'Bearer ${s.token}';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(const Duration(seconds: 20)),
      ).timeout(const Duration(seconds: 20));
    } on Exception catch (e) {
      throw PanoptoException('network', '$e');
    }
    Map<String, Object?> json = const {};
    if (response.body.isNotEmpty &&
        (response.headers['content-type'] ?? '').contains('json')) {
      try {
        json = (jsonDecode(response.body) as Map).cast<String, Object?>();
      } on Object {
        // Not ours to read.
      }
    }
    final status = response.statusCode;
    if (status == 401) {
      throw const PanoptoException('network', 'signed out');
    }
    if (status >= 500 || status == 429 && path != '/pairs') {
      throw PanoptoException('network', 'server $status');
    }
    return (status, json);
  }

  static VaultBox? _box(Object? json) =>
      json is Map ? VaultBox.fromJson(json.cast<String, Object?>()) : null;

  Future<VaultRead> read() async {
    final (_, json) = await _call('GET', '/vault');
    return VaultRead(
      vault: _box(json['vault']),
      pairs: [
        for (final p in json['pairs'] as List? ?? const [])
          (p as Map).cast<String, Object?>(),
      ],
      now: (json['now'] as num?)?.toInt() ?? 0,
    );
  }

  /// The vault, held by [owner] for a minute. Throws `busy` while another
  /// device holds it, `no_vault` when there's none.
  Future<VaultBox> lease(String owner) async {
    final (status, json) = await _call('POST', '/vault/lease', {
      'owner': owner,
    });
    if (status == 409) throw const PanoptoException('busy');
    if (status == 404) throw const PanoptoException('no_vault');
    return _box(json['vault'])!;
  }

  Future<void> release(String owner) =>
      _call('POST', '/vault/release', {'owner': owner});

  /// Saves over version [expect] (0: there's none yet). Returns the new
  /// version; throws [VaultConflict] when the vault changed meanwhile.
  Future<int> put({
    required int expect,
    required String kid,
    required String nonce,
    required String ct,
    String? owner,
  }) async {
    final (status, json) = await _call('PUT', '/vault', {
      'expect': expect,
      'owner': ?owner,
      'kid': kid,
      'nonce': nonce,
      'ct': ct,
      'device': thisDeviceName(),
    });
    if (status == 409) throw VaultConflict(_box(json['vault']));
    if (status != 200) throw PanoptoException('network', 'server $status');
    return (json['v'] as num).toInt();
  }

  /// Panopto refused version [expect]'s sign-in.
  Future<void> refused(int expect) =>
      _call('POST', '/vault/refused', {'expect': expect});

  /// Claims the account's look: null if a device looked in the last 3
  /// hours (unless [force]), otherwise the claim's time.
  Future<int?> claimLook({required bool force}) async {
    final (status, json) = await _call('POST', '/vault/look', {'force': force});
    if (status != 200 || json['ok'] != true) return null;
    return (json['lookedAt'] as num).toInt();
  }

  /// Gives back the claim made at [at] (the look failed for a passing
  /// reason).
  Future<void> unclaimLook(int at) =>
      _call('POST', '/vault/unlook', {'at': at});

  Future<void> delete() => _call('DELETE', '/vault');

  // ---------------------------------------------------------- pairing --

  Future<(int, Map<String, Object?>)> pairCall(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) => _call(method, '/pairs$path', body);
}

/// The vault changed since it was read: [vault] is the current one.
class VaultConflict extends PanoptoException {
  const VaultConflict(this.vault) : super('conflict');

  final VaultBox? vault;
}
