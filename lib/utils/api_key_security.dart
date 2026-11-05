import 'dart:convert';

class ApiKeySecurity {
  // 256-bit Obfuscation/Encryption Key
  static const String _secretSeed = "MP_PROTO_2026_FIRST_SHIFT_NOTE_SECURE_KEY_STRING";

  // 🔐 API Key 암호화 (개발 환경 및 보안 등록용)
  static String encrypt(String rawKey) {
    final cleanInput = rawKey.replaceAll('\n', '').replaceAll('\r', '').trim();
    if (cleanInput.isEmpty) return '';
    
    final keyBytes = utf8.encode(_secretSeed);
    final rawBytes = utf8.encode(cleanInput);

    final encryptedBytes = List<int>.generate(rawBytes.length, (i) {
      return rawBytes[i] ^ keyBytes[i % keyBytes.length];
    });

    return base64.encode(encryptedBytes);
  }

  // 🔓 암호화된 API Key 복호화 (앱 실행 중 메모리 상에서만 안전 복호화)
  static String decrypt(String encryptedKey) {
    final cleanInput = encryptedKey.replaceAll('\n', '').replaceAll('\r', '').trim();
    if (cleanInput.isEmpty) return '';
    
    // 만약 이미 평문 sk- 키인 경우 호환성을 위해 유연하게 반환
    if (cleanInput.startsWith('sk-')) return cleanInput;

    try {
      final encryptedBytes = base64.decode(cleanInput);
      final keyBytes = utf8.encode(_secretSeed);

      final rawBytes = List<int>.generate(encryptedBytes.length, (i) {
        return encryptedBytes[i] ^ keyBytes[i % keyBytes.length];
      });

      return utf8.decode(rawBytes);
    } catch (_) {
      return cleanInput;
    }
  }
}
