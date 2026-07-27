class ActivateLicenseRequest {
  final String code;
  final String hwid;
  final String deviceName;

  ActivateLicenseRequest({
    required this.code,
    required this.hwid,
    required this.deviceName,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'hwid': hwid,
    'device_name': deviceName,
  };
}

class EncryptedRequest {
  final String payload;
  final String iv;
  final int timestamp;
  final String nonce;
  final String signature;

  EncryptedRequest({
    required this.payload,
    required this.iv,
    required this.timestamp,
    required this.nonce,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
    'payload': payload,
    'iv': iv,
    'timestamp': timestamp,
    'nonce': nonce,
    'signature': signature,
  };
}

class EncryptedResponse {
  final bool encrypted;
  final String payload;
  final String iv;
  final String signature;
  final int timestamp;

  EncryptedResponse({
    required this.encrypted,
    required this.payload,
    required this.iv,
    required this.signature,
    required this.timestamp,
  });

  factory EncryptedResponse.fromJson(Map<String, dynamic> json) {
    return EncryptedResponse(
      encrypted: json['encrypted'] ?? false,
      payload: json['payload'] ?? '',
      iv: json['iv'] ?? '',
      signature: json['signature'] ?? '',
      timestamp: json['timestamp'] ?? 0,
    );
  }
}

class LicenseData {
  final String code;
  final String type;
  final String status;
  final String hwid;
  final DateTime? activatedAt;
  final DateTime expiresAt;

  LicenseData({
    required this.code,
    required this.type,
    required this.status,
    required this.hwid,
    this.activatedAt,
    required this.expiresAt,
  });

  factory LicenseData.fromJson(Map<String, dynamic> json) {
    return LicenseData(
      code: json['code'],
      type: json['type'],
      status: json['status'],
      hwid: json['hwid'],
      activatedAt: json['activated_at'] != null 
          ? DateTime.parse(json['activated_at']) 
          : null,
      expiresAt: DateTime.parse(json['expires_at']),
    );
  }
}

class ActivateLicenseResponse {
  final bool valid;
  final String? message;
  final String? error;
  final LicenseData? data;

  ActivateLicenseResponse({
    required this.valid,
    this.message,
    this.error,
    this.data,
  });

  factory ActivateLicenseResponse.fromJson(Map<String, dynamic> json) {
    return ActivateLicenseResponse(
      valid: json['valid'] ?? false,
      message: json['message'],
      error: json['error'],
      data: json['data'] != null ? LicenseData.fromJson(json['data']) : null,
    );
  }
}

class VerifyLicenseRequest {
  final String code;
  final String hwid;

  VerifyLicenseRequest({
    required this.code,
    required this.hwid,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'hwid': hwid,
  };
}

class VerifyLicenseResponse {
  final bool valid;
  final String? message;
  final String? error;
  final LicenseData? data;

  VerifyLicenseResponse({
    required this.valid,
    this.message,
    this.error,
    this.data,
  });

  factory VerifyLicenseResponse.fromJson(Map<String, dynamic> json) {
    return VerifyLicenseResponse(
      valid: json['valid'] ?? false,
      message: json['message'],
      error: json['error'],
      data: json['data'] != null ? LicenseData.fromJson(json['data']) : null,
    );
  }
}
