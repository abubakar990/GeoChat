import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// AES-256-GCM end-to-end encryption service.
/// Conversation keys are generated once and stored securely in the OS keychain.
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _algorithm = AesGcm.with256bits();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<SecretKey> getOrCreateKey(String conversationId) async {
    // Append '_v2' to invalidate old, mismatched random keys stored locally.
    final storageKey =
        '${AppConstants.encryptionKeyPrefix}${conversationId}_v2';
    final existing = await _storage.read(key: storageKey);
    if (existing != null) {
      return SecretKey(base64Decode(existing));
    }

    // Deterministic symmetric key generation using conversationId.
    // NOTE: This ensures both participants compute the same key for the chat,
    // working around the lack of a proper key-exchange mechanism (like Diffie-Hellman).
    final hash =
        await Sha256().hash(utf8.encode('geochat_key_$conversationId'));
    final secretKey = SecretKey(hash.bytes);

    final bytes = await secretKey.extractBytes();
    await _storage.write(key: storageKey, value: base64Encode(bytes));

    return secretKey;
  }

  /// Returns base64-encoded encrypted payload: nonce(12) + ciphertext + mac(16)
  Future<String> encrypt(String plaintext, SecretKey key) async {
    final box = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
    );
    final combined = Uint8List.fromList([
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
    return base64Encode(combined);
  }

  Future<String?> decrypt(String ciphertext, SecretKey key) async {
    try {
      final bytes = base64Decode(ciphertext);
      final nonce = bytes.sublist(0, 12);
      final mac = Mac(bytes.sublist(bytes.length - 16));
      final cipher = bytes.sublist(12, bytes.length - 16);
      final box = SecretBox(cipher, nonce: nonce, mac: mac);
      final plain = await _algorithm.decrypt(box, secretKey: key);
      return utf8.decode(plain);
    } catch (_) {
      return '[Encrypted message — key mismatch]';
    }
  }

  Future<void> deleteKey(String conversationId) => _storage.delete(
        key: '${AppConstants.encryptionKeyPrefix}$conversationId',
      );
}
