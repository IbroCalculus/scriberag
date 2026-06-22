import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:scriberag/core/constants.dart';

class EncryptionService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Uint8List? _masterKey;

  // Initialize and load key from secure storage, or generate one if it doesn't exist
  Future<void> init() async {
    if (_masterKey != null) return;

    String? base64Key = await _secureStorage.read(key: AppConstants.dbEncryptionKeySecureKey);
    if (base64Key == null) {
      // Generate a new 256-bit key (32 bytes)
      final secureRandom = Random.secure();
      final keyBytes = Uint8List.fromList(List.generate(32, (_) => secureRandom.nextInt(256)));
      base64Key = base64.encode(keyBytes);
      await _secureStorage.write(
        key: AppConstants.dbEncryptionKeySecureKey,
        value: base64Key,
      );
      _masterKey = keyBytes;
    } else {
      _masterKey = base64.decode(base64Key);
    }
  }

  // Get raw key bytes (useful for Hive encryption)
  Future<Uint8List> getHiveEncryptionKey() async {
    await init();
    // HiveAesCipher requires exactly a 32-byte (256-bit) key
    return _masterKey!.sublist(0, 32);
  }

  // Retrieve file encryption key (first 32 bytes of the secure key for AES-256)
  Future<enc.Key> _getFileEncryptionKey() async {
    await init();
    final fileKeyBytes = _masterKey!.sublist(0, 32);
    return enc.Key(fileKeyBytes);
  }

  // Encrypt file bytes
  Future<List<int>> encryptBytes(List<int> plainBytes) async {
    final key = await _getFileEncryptionKey();
    // Generate random 16-byte IV
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);
    
    // Combine IV (16 bytes) + Encrypted cipher text
    final combined = Uint8List(16 + encrypted.bytes.length);
    combined.setRange(0, 16, iv.bytes);
    combined.setRange(16, combined.length, Uint8List.fromList(encrypted.bytes));
    
    return combined;
  }

  // Decrypt file bytes
  Future<List<int>> decryptBytes(List<int> encryptedBytes) async {
    if (encryptedBytes.length < 16) {
      throw Exception("Ciphertext too short (missing IV)");
    }
    final key = await _getFileEncryptionKey();
    
    // Extract IV (first 16 bytes)
    final ivBytes = Uint8List.fromList(encryptedBytes.sublist(0, 16));
    final iv = enc.IV(ivBytes);
    
    // Extract ciphertext
    final cipherBytes = Uint8List.fromList(encryptedBytes.sublist(16));
    
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
    
    return decrypted;
  }

  // Helper to encrypt a file on disk and delete the original unencrypted file
  Future<void> encryptFile(String sourcePath, String targetPath) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception("Source file not found for encryption: $sourcePath");
    }
    
    final bytes = await file.readAsBytes();
    final encryptedBytes = await encryptBytes(bytes);
    
    final targetFile = File(targetPath);
    // Ensure parent directories exist
    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsBytes(encryptedBytes, flush: true);
    
    // Delete raw unencrypted file for privacy
    await file.delete();
  }

  // Helper to decrypt a file from disk
  Future<List<int>> decryptFileToBytes(String encryptedPath) async {
    final file = File(encryptedPath);
    if (!await file.exists()) {
      throw Exception("Encrypted file not found at $encryptedPath");
    }
    
    final bytes = await file.readAsBytes();
    return decryptBytes(bytes);
  }
}
