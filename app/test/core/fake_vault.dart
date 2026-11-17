import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The sync server's `/v1/panopto` endpoints for one account, with the same
/// rules as `server/src/panopto-vault.ts` (tested there against the real
/// Durable Object).
class FakeVault {
  static const token = 'session-token';

  Map<String, Object?>? vault;
  String? leaseOwner;
  DateTime leaseUntil = DateTime(2000);
  final pairs = <String, Map<String, Object?>>{};
  var _pairIds = 0;
  DateTime Function() clock = DateTime.now;

  /// While true, every request fails as if offline.
  bool offline = false;

  /// While set, PUTs fail as if the connection dropped (after the server
  /// may or may not have seen them: here it hasn't).
  bool dropPuts = false;

  final requests = <http.Request>[];

  /// Called on every change, like the server's `{"t":"panopto"}`.
  final changes = StreamController<void>.broadcast(sync: true);

  bool _leaseHeld(String? owner) =>
      vault != null && leaseUntil.isAfter(clock()) && leaseOwner != owner;

  late final client = MockClient((request) async {
    requests.add(request);
    if (offline) throw http.ClientException('offline');
    if (request.headers['Authorization'] != 'Bearer $token') {
      return http.Response('Unauthorized', 401);
    }
    final path = request.url.path.replaceFirst('/v1/panopto', '');
    final body = request.body.isEmpty
        ? const <String, Object?>{}
        : (jsonDecode(request.body) as Map).cast<String, Object?>();
    final now = clock();
    pairs.removeWhere(
      (_, p) => (p['expiresAt']! as int) < now.millisecondsSinceEpoch,
    );
    http.Response json(Object? b, [int status = 200]) => http.Response(
      jsonEncode(b),
      status,
      headers: {'content-type': 'application/json'},
    );
    final none = http.Response('', 204);
    void changed() => changes.add(null);

    switch ((request.method, path)) {
      case ('GET', '/vault'):
        return json({
          'vault': vault,
          'pairs': pairs.values.toList(),
          'now': now.millisecondsSinceEpoch,
        });
      case ('POST', '/vault/lease'):
        if (vault == null) return json({'error': 'no_vault'}, 404);
        if (_leaseHeld(body['owner'] as String?)) {
          return json({'error': 'busy'}, 409);
        }
        leaseOwner = body['owner'] as String?;
        leaseUntil = now.add(const Duration(seconds: 60));
        return json({'vault': vault});
      case ('POST', '/vault/release'):
        if (leaseOwner == body['owner']) {
          leaseOwner = null;
          leaseUntil = DateTime(2000);
        }
        return none;
      case ('PUT', '/vault'):
        if (dropPuts) throw http.ClientException('connection dropped');
        final current = (vault?['v'] as int?) ?? 0;
        if (body['expect'] != current || _leaseHeld(body['owner'] as String?)) {
          return json({'error': 'conflict', 'vault': vault}, 409);
        }
        if (vault != null && vault!['kid'] != body['kid']) pairs.clear();
        vault = {
          'v': current + 1,
          'kid': body['kid'],
          'nonce': body['nonce'],
          'ct': body['ct'],
          'device': body['device'],
          'updatedAt': now.millisecondsSinceEpoch,
          'lookedAt': vault?['lookedAt'] ?? 0,
          'refused': body['refused'] == true,
        };
        leaseOwner = null;
        leaseUntil = DateTime(2000);
        changed();
        return json({'v': current + 1});
      case ('POST', '/vault/refused'):
        if (vault == null || vault!['v'] != body['expect']) {
          return json({'error': 'conflict', 'vault': vault}, 409);
        }
        vault!['refused'] = true;
        changed();
        return none;
      case ('POST', '/vault/look'):
        if (vault == null) return json({'error': 'no_vault'}, 404);
        final at = vault!['lookedAt']! as int;
        if (body['force'] != true &&
            now.millisecondsSinceEpoch - at <
                const Duration(hours: 3).inMilliseconds) {
          return json({'ok': false, 'lookedAt': at});
        }
        vault!['lookedAt'] = now.millisecondsSinceEpoch;
        return json({'ok': true, 'lookedAt': now.millisecondsSinceEpoch});
      case ('POST', '/vault/unlook'):
        if (vault?['lookedAt'] == body['at']) vault!['lookedAt'] = 0;
        return none;
      case ('DELETE', '/vault'):
        vault = null;
        pairs.clear();
        changed();
        return none;
      case ('POST', '/pairs'):
        if (vault == null) return json({'error': 'no_vault'}, 404);
        final id = 'pair-${++_pairIds}';
        final expiresAt = now
            .add(const Duration(minutes: 10))
            .millisecondsSinceEpoch;
        pairs[id] = {
          'id': id,
          'device': body['device'],
          'commit': body['commit'],
          'aPub': null,
          'bPub': null,
          'nonce': null,
          'wrapped': null,
          'kid': null,
          'denied': false,
          'expiresAt': expiresAt,
        };
        changed();
        return json({'id': id, 'expiresAt': expiresAt});
    }
    final pairPath = RegExp(r'^/pairs/([^/]+)$').firstMatch(path);
    if (pairPath != null) {
      final id = pairPath.group(1)!;
      final pair = pairs[id];
      if (pair == null) return json({'error': 'no_pair'}, 404);
      switch (request.method) {
        case 'GET':
          return json(pair);
        case 'DELETE':
          pairs.remove(id);
          changed();
          return none;
        case 'PATCH':
          if (body.containsKey('denied')) {
            pair['denied'] = true;
          } else if (body.containsKey('aPub')) {
            if (pair['aPub'] != null) return json({'error': 'answered'}, 409);
            pair['aPub'] = body['aPub'];
          } else if (body.containsKey('bPub')) {
            if (pair['aPub'] == null || pair['bPub'] != null) {
              return json({'error': 'out_of_order'}, 409);
            }
            pair['bPub'] = body['bPub'];
            pair['nonce'] = body['nonce'];
          } else if (body.containsKey('wrapped')) {
            if (pair['bPub'] == null || pair['wrapped'] != null) {
              return json({'error': 'out_of_order'}, 409);
            }
            pair['wrapped'] = body['wrapped'];
            pair['kid'] = body['kid'];
          } else {
            return json({'error': 'bad_fields'}, 400);
          }
          changed();
          return none;
      }
    }
    return http.Response('not found', 404);
  });
}

/// One device's secure storage.
class MemoryStorage extends FlutterSecureStorage {
  MemoryStorage();

  final values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values.remove(key);
}
