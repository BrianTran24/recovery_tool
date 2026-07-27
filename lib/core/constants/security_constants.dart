import 'dart:typed_data';

class SecurityConstants {
  // Obfuscation mask
  static const List<int> _mask = [0x5A, 0x1F, 0x8C, 0x33];

  // Obfuscated keys (XORed with _mask)
  static const List<int> _obfuscatedAesKey = [
    107, 45, 191, 7, 111, 41, 187, 11, 99, 47, 189, 1, 105, 43, 185, 5, 
    109, 39, 181, 3, 107, 45, 191, 7, 111, 41, 187, 11, 99, 47, 189, 1
  ];

  static const List<int> _obfuscatedPublic = [
    116, 33, 230, 207, 109, 239, 110, 65, 211, 216, 203, 132, 145, 218, 85, 191, 
    175, 18, 209, 252, 182, 142, 37, 171, 152, 52, 210, 92, 238, 59, 33, 41
  ];

  static const List<int> _obfuscatedPrivate = [
    45, 248, 156, 224, 67, 239, 142, 45, 241, 243, 65, 180, 189, 226, 250, 252, 
    72, 224, 164, 206, 149, 167, 219, 85, 20, 234, 103, 244, 66, 234, 172, 244, 
    116, 33, 230, 207, 109, 239, 110, 65, 211, 216, 203, 132, 145, 218, 85, 191, 
    175, 18, 209, 252, 182, 142, 37, 171, 152, 52, 210, 92, 238, 59, 33, 41
  ];

  /// Get De-obfuscated AES Key (32 bytes)
  static Uint8List get aesKey => _deobfuscate(_obfuscatedAesKey);

  /// Get De-obfuscated Server Ed25519 Public Key (32 bytes)
  static Uint8List get serverEd25519PublicKey => _deobfuscate(_obfuscatedPublic);

  /// Get De-obfuscated Client Ed25519 Private Key (if needed for client signing)
  static Uint8List get ed25519PrivateKey => _deobfuscate(_obfuscatedPrivate);

  static Uint8List _deobfuscate(List<int> encrypted) {
    return Uint8List.fromList(
      List.generate(encrypted.length, (i) => encrypted[i] ^ _mask[i % _mask.length]),
    );
  }
}
