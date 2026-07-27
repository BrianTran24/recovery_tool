class SecurityConstants {
  // Payload Encryption Key (AES-256 Key) - 32 bytes
  // In a real production app, these should be managed securely, 
  // but as per requirements, they are hardcoded in the client.
  static const String aesKey = '12345678901234567890123456789012';

  // Server Ed25519 Public Key (Hex or Base64 depending on implementation)
  // This is the key used to verify the server's signature.
  // Note: This should be updated with the actual key from Admin API `GET /api/v1/admin/security-info`
  static const String serverEd25519PublicKey = '68c7e96b6b7d15668e367808298018e6988220027f311c63866657904791336c'; // Placeholder
}
