import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import '../constants/security_constants.dart';
import '../models/license_models.dart';

class SecurityService {
  final _aesGcm = AesGcm.with256bits();
  final _hmacSha256 = Hmac.sha256();
  final _ed25519 = Ed25519();
  final _uuid = const Uuid();

  late final SecretKey _encryptionKey;

  SecurityService() {
    _encryptionKey = SecretKey(utf8.encode(SecurityConstants.aesKey));
  }

  /// Encrypts a JSON request according to the specified protocol.
  Future<EncryptedRequest> encryptRequest(Map<String, dynamic> requestData) async {
    final jsonString = jsonEncode(requestData);
    final payloadBytes = utf8.encode(jsonString);

    // 2. Generate random 12-byte IV
    final secretBox = await _aesGcm.encrypt(
      payloadBytes,
      secretKey: _encryptionKey,
    );

    final payloadBase64 = base64.encode(secretBox.cipherText);
    final ivBase64 = base64.encode(secretBox.nonce);

    // 4. Current Timestamp and Nonce (UUID v4)
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = _uuid.v4();

    // 5. Calculate HMAC-SHA256 Signature
    // HMAC(payload + ":" + timestamp + ":" + nonce, Key)
    final signatureData = '$payloadBase64:$timestamp:$nonce';
    final hmac = await _hmacSha256.calculateMac(
      utf8.encode(signatureData),
      secretKey: _encryptionKey,
    );
    final signatureBase64 = base64.encode(hmac.bytes);

    return EncryptedRequest(
      payload: payloadBase64,
      iv: ivBase64,
      timestamp: timestamp,
      nonce: nonce,
      signature: signatureBase64,
    );
  }

  /// Decrypts and verifies a response from the server.
  Future<Map<String, dynamic>> decryptResponse(EncryptedResponse response, {String? overridePublicKey}) async {
    if (!response.encrypted) {
      throw Exception('Response is not encrypted');
    }

    // 2. Verify Server Ed25519 Signature
    final publicKeyHex = overridePublicKey ?? SecurityConstants.serverEd25519PublicKey;
    final publicKeyBytes = _decodeHex(publicKeyHex);
    final signatureBytes = base64.decode(response.signature);
    final payloadBytes = utf8.encode(response.payload);

    final isSignatureValid = await _ed25519.verify(
      payloadBytes,
      signature: Signature(signatureBytes, publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519)),
    );

    if (!isSignatureValid) {
      // SECURITY WARNING: Server spoofing detected!
      throw SecurityException('SERVER SPOOFING DETECTED: Invalid Ed25519 signature!');
    }

    // 3. Decrypt AES-256-GCM
    final ciphertext = base64.decode(response.payload);
    final iv = base64.decode(response.iv);

    final secretBox = SecretBox(
      ciphertext,
      nonce: iv,
      mac: Mac(ciphertext.sublist(ciphertext.length - 16)), // AES-GCM tag is the last 16 bytes
    );
    
    // The cryptography package's AesGcm expects the MAC separately if not already in secretBox
    // Wait, cryptography's encrypt method returns a SecretBox which contains ciphertext and mac.
    // When decrypting, we need to handle how the backend sends it.
    // Usually, AES-GCM ciphertext from Go/OpenSSL includes the tag at the end.
    
    Uint8List actualCiphertext;
    Uint8List macBytes;
    
    if (ciphertext.length > 16) {
      actualCiphertext = Uint8List.fromList(ciphertext.sublist(0, ciphertext.length - 16));
      macBytes = Uint8List.fromList(ciphertext.sublist(ciphertext.length - 16));
    } else {
      throw Exception('Invalid ciphertext length');
    }

    final boxToDecrypt = SecretBox(
      actualCiphertext,
      nonce: iv,
      mac: Mac(macBytes),
    );

    final decryptedBytes = await _aesGcm.decrypt(
      boxToDecrypt,
      secretKey: _encryptionKey,
    );

    final jsonString = utf8.decode(decryptedBytes);
    return jsonDecode(jsonString);
  }

  Uint8List _decodeHex(String hex) {
    var result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  @override
  String toString() => message;
}
