import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:recovery_tool/core/service/security_service.dart';
import 'package:recovery_tool/core/constants/security_constants.dart';
import 'package:recovery_tool/core/models/license_models.dart';

void main() {
  late SecurityService securityService;

  setUp(() {
    securityService = SecurityService();
  });

  group('SecurityService Tests', () {
    test('encryptRequest should produce a valid EncryptedRequest', () async {
      final requestData = {'code': 'TEST-CODE', 'hwid': 'TEST-HWID'};
      final encryptedReq = await securityService.encryptRequest(requestData);

      expect(encryptedReq.payload, isNotEmpty);
      expect(encryptedReq.iv, isNotEmpty);
      expect(encryptedReq.timestamp, isNotNull);
      expect(encryptedReq.nonce, isNotEmpty);
      expect(encryptedReq.signature, isNotEmpty);

      // Verify HMAC
      final signatureData = '${encryptedReq.payload}:${encryptedReq.timestamp}:${encryptedReq.nonce}';
      final hmacSha256 = Hmac.sha256();
      final key = SecretKey(SecurityConstants.aesKey);
      final expectedHmac = await hmacSha256.calculateMac(
        utf8.encode(signatureData),
        secretKey: key,
      );
      expect(encryptedReq.signature, base64.encode(expectedHmac.bytes));
    });

    test('decryptResponse should correctly decrypt a valid response and verify signature', () async {
      // 1. Prepare data
      final originalData = {'valid': true, 'message': 'Success'};
      final jsonString = jsonEncode(originalData);
      final payloadBytes = utf8.encode(jsonString);

      // 2. Encrypt manually to simulate server response
      final aesGcm = AesGcm.with256bits();
      final key = SecretKey(SecurityConstants.aesKey);
      final secretBox = await aesGcm.encrypt(payloadBytes, secretKey: key);
      
      final combinedCiphertext = [...secretBox.cipherText, ...secretBox.mac.bytes];
      final payloadBase64 = base64.encode(combinedCiphertext);
      final ivBase64 = base64.encode(secretBox.nonce);

      // 3. Sign manually to simulate server signature (Ed25519)
      final ed25519 = Ed25519();
      final keyPair = await ed25519.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      
      final signature = await ed25519.sign(
        utf8.encode(payloadBase64),
        keyPair: keyPair,
      );
      
      final publicKeyHex = publicKey.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final signatureBase64 = base64.encode(signature.bytes);

      // 4. Test decryption
      final encryptedRes = EncryptedResponse(
        encrypted: true,
        payload: payloadBase64,
        iv: ivBase64,
        signature: signatureBase64,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      final decryptedData = await securityService.decryptResponse(
        encryptedRes, 
        overridePublicKey: publicKeyHex,
      );

      expect(decryptedData['valid'], true);
      expect(decryptedData['message'], 'Success');
    });

    test('decryptResponse should throw SecurityException on invalid signature', () async {
      final originalData = {'valid': true};
      final jsonString = jsonEncode(originalData);
      final aesGcm = AesGcm.with256bits();
      final key = SecretKey(SecurityConstants.aesKey);
      final secretBox = await aesGcm.encrypt(utf8.encode(jsonString), secretKey: key);
      
      final combinedCiphertext = [...secretBox.cipherText, ...secretBox.mac.bytes];
      final payloadBase64 = base64.encode(combinedCiphertext);
      
      final ed25519 = Ed25519();
      final keyPair = await ed25519.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final publicKeyHex = publicKey.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      final encryptedRes = EncryptedResponse(
        encrypted: true,
        payload: payloadBase64,
        iv: base64.encode(secretBox.nonce),
        signature: base64.encode(Uint8List(64)), // Invalid signature
        timestamp: 0,
      );

      expect(
        () => securityService.decryptResponse(encryptedRes, overridePublicKey: publicKeyHex),
        throwsA(isA<SecurityException>()),
      );
    });
  });
}
