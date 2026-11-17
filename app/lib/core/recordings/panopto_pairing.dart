import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';

import '../dev/dev_log.dart';
import 'panopto_api.dart';
import 'panopto_vault.dart';

/// Pairing: hands the vault key to a new device (B) from one that holds it
/// (A), through the sync server, which only relays public keys, a commit
/// and ciphertext.
///
/// 1. B makes an X25519 key pair and a nonce, and asks with its name and
///    `commit = SHA-256(B.pub . nonce)`.
/// 2. A (any device holding the key, by itself) answers with its own
///    public key.
/// 3. B reveals its public key and nonce; A checks them against the commit.
///    Committing first stops a server from picking a key that happens to
///    give the same code.
/// 4. Both show a 6-digit code made from the request id, both keys and the
///    nonce. A server that swapped in its own keys gets different codes.
/// 5. On Allow, A sends the vault key encrypted with a key both derive
///    (X25519, then HKDF-SHA256); B opens it and checks its kid.
abstract final class PairingCrypto {
  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();
  static const _info = 'leccheck-pair-v1';

  static String _b64(List<int> bytes) => base64Url.encode(bytes);

  static Future<(SimpleKeyPair, String)> keyPair() async {
    final pair = await _x25519.newKeyPair();
    return (pair, _b64((await pair.extractPublicKey()).bytes));
  }

  static String nonce() {
    final random = Random.secure();
    return _b64(List.generate(16, (_) => random.nextInt(256)));
  }

  static String commit(String bPub, String nonce) =>
      _b64(sha256.convert(utf8.encode('$bPub.$nonce')).bytes);

  /// What both devices show.
  static String code(String id, String aPub, String bPub, String nonce) {
    final h = sha256
        .convert(utf8.encode('$_info|$id|$aPub|$bPub|$nonce'))
        .bytes;
    final n = (h[0] << 24 | h[1] << 16 | h[2] << 8 | h[3]) % 1000000;
    return n.toString().padLeft(6, '0');
  }

  static Future<SecretKey> _wrapKey(
    SimpleKeyPair mine,
    String theirPub,
    String id,
  ) async {
    final shared = await _x25519.sharedSecretKey(
      keyPair: mine,
      remotePublicKey: SimplePublicKey(
        base64Url.decode(theirPub),
        type: KeyPairType.x25519,
      ),
    );
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: shared,
      nonce: utf8.encode(id),
      info: utf8.encode(_info),
    );
  }

  static Future<String> wrap(
    SimpleKeyPair mine,
    String theirPub,
    String id,
    List<int> vaultKey,
  ) async {
    final box = await _aes.encrypt(
      vaultKey,
      secretKey: await _wrapKey(mine, theirPub, id),
      aad: utf8.encode(id),
    );
    return _b64(box.concatenation());
  }

  static Future<List<int>> unwrap(
    SimpleKeyPair mine,
    String theirPub,
    String id,
    String wrapped,
  ) async {
    final box = SecretBox.fromConcatenation(
      base64Url.decode(wrapped),
      nonceLength: _aes.nonceLength,
      macLength: 16,
    );
    return _aes.decrypt(
      box,
      secretKey: await _wrapKey(mine, theirPub, id),
      aad: utf8.encode(id),
    );
  }
}

/// Where a new device's request stands.
sealed class PairingStep {
  const PairingStep();
}

/// Waiting for a device holding the key to answer (its app isn't open).
class PairingWaiting extends PairingStep {
  const PairingWaiting();
}

/// Compare [code] with the other device's, and tap Allow there.
class PairingCode extends PairingStep {
  const PairingCode(this.code);

  final String code;
}

class PairingDone extends PairingStep {
  const PairingDone(this.key);

  final VaultKey key;
}

class PairingDenied extends PairingStep {
  const PairingDenied();
}

/// Expired, cancelled on the other device, or the vault was set up again.
class PairingGone extends PairingStep {
  const PairingGone();
}

/// A new device asking for the vault key (B).
class PairingRequest {
  PairingRequest._(this._client, this._pair, this._bPub, this._nonce, this.id);

  final VaultClient _client;
  final SimpleKeyPair _pair;
  final String _bPub;
  final String _nonce;
  final String id;
  bool _revealed = false;

  /// Asks the account's devices. Throws [PanoptoException].
  static Future<PairingRequest> start(VaultClient client) async {
    final (pair, pub) = await PairingCrypto.keyPair();
    final nonce = PairingCrypto.nonce();
    final (status, json) = await client.pairCall('POST', '', {
      'device': thisDeviceName(),
      'commit': PairingCrypto.commit(pub, nonce),
    });
    if (status == 404) throw const PanoptoException('no_vault');
    if (status != 200) throw PanoptoException('network', 'pairing $status');
    return PairingRequest._(client, pair, pub, nonce, json['id']! as String);
  }

  /// Reads the request and takes the next step. [userId]: the account the
  /// key is for.
  Future<PairingStep> poll(String userId) async {
    final (status, pair) = await _client.pairCall('GET', '/$id');
    if (status == 404) return const PairingGone();
    if (pair['denied'] == true) return const PairingDenied();
    final aPub = pair['aPub'] as String?;
    if (aPub == null) return const PairingWaiting();
    if (!_revealed && pair['bPub'] == null) {
      final (patched, _) = await _client.pairCall('PATCH', '/$id', {
        'bPub': _bPub,
        'nonce': _nonce,
      });
      if (patched == 404) return const PairingGone();
      _revealed = true;
    }
    if (pair['bPub'] != null && pair['bPub'] != _bPub) {
      // Not ours: someone else answered in our name.
      return const PairingGone();
    }
    final wrapped = pair['wrapped'] as String?;
    if (wrapped == null) {
      return PairingCode(PairingCrypto.code(id, aPub, _bPub, _nonce));
    }
    final List<int> bytes;
    try {
      bytes = await PairingCrypto.unwrap(_pair, aPub, id, wrapped);
    } on Object catch (e) {
      DevLog.add('Panopto pairing: the key didn\'t open ($e)');
      return const PairingGone();
    }
    if (VaultKey.kidOf(bytes) != pair['kid']) return const PairingGone();
    await cancel();
    return PairingDone(
      VaultKey(userId: userId, bytes: Uint8List.fromList(bytes)),
    );
  }

  /// Withdraws the request (best effort).
  Future<void> cancel() async {
    try {
      await _client.pairCall('DELETE', '/$id');
    } on PanoptoException catch (e) {
      DevLog.add('Panopto pairing not withdrawn: $e');
    }
  }
}

/// A request a device holding the key can allow: [code] to compare.
class PairingPrompt {
  const PairingPrompt({
    required this.id,
    required this.device,
    required this.code,
  });

  final String id;
  final String device;
  final String code;
}

/// A device holding the vault key (A): answers new devices' requests, and
/// allows or denies them. The key pairs live only in memory: a request
/// answered before the app closed waits for its 10 minutes to end.
class PairingResponder {
  final _mine = <String, SimpleKeyPair>{};
  final _prompted = <String>{};

  /// Answers new requests, and returns those ready to ask about (each
  /// once).
  Future<List<PairingPrompt>> check(VaultClient client) async {
    final pairs = (await client.read()).pairs;
    final prompts = <PairingPrompt>[];
    for (final pair in pairs) {
      final id = pair['id']! as String;
      if (pair['denied'] == true || pair['wrapped'] != null) continue;
      if (pair['aPub'] == null) {
        final (keys, pub) = await PairingCrypto.keyPair();
        final (status, _) = await client.pairCall('PATCH', '/$id', {
          'aPub': pub,
        });
        // 409: another of the account's devices answered first.
        if (status == 204) _mine[id] = keys;
        continue;
      }
      final keys = _mine[id];
      final bPub = pair['bPub'] as String?;
      final nonce = pair['nonce'] as String?;
      if (keys == null || bPub == null || nonce == null) continue;
      if (_prompted.contains(id)) continue;
      if (PairingCrypto.commit(bPub, nonce) != pair['commit']) {
        DevLog.add('Panopto pairing: a key that doesn\'t match its commit');
        await deny(client, id);
        continue;
      }
      final aPub = base64Url.encode((await keys.extractPublicKey()).bytes);
      _prompted.add(id);
      prompts.add(
        PairingPrompt(
          id: id,
          device: pair['device'] as String? ?? '',
          code: PairingCrypto.code(id, aPub, bPub, nonce),
        ),
      );
    }
    return prompts;
  }

  /// Sends [key] to the device of [prompt].
  Future<void> allow(
    VaultClient client,
    PairingPrompt prompt,
    VaultKey key,
  ) async {
    final keys = _mine.remove(prompt.id);
    if (keys == null) throw const PanoptoException('pair_gone');
    final (status, pair) = await client.pairCall('GET', '/${prompt.id}');
    final bPub = pair['bPub'] as String?;
    if (status != 200 || bPub == null) {
      throw const PanoptoException('pair_gone');
    }
    final wrapped = await PairingCrypto.wrap(keys, bPub, prompt.id, key.bytes);
    final (patched, _) = await client.pairCall('PATCH', '/${prompt.id}', {
      'wrapped': wrapped,
      'kid': key.kid,
    });
    if (patched != 204) throw const PanoptoException('pair_gone');
    DevLog.add('Panopto: allowed ${prompt.device}');
  }

  Future<void> deny(VaultClient client, String id) async {
    _mine.remove(id);
    await client.pairCall('PATCH', '/$id', {'denied': true});
  }
}
