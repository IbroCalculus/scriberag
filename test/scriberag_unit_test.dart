import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:scriberag/data/models/journal_entry.dart';
import 'package:scriberag/data/services/ai_service.dart';
import 'package:encrypt/encrypt.dart' as enc;

void main() {
  group('Vector Similarity Tests', () {
    final aiService = AIService();

    test('Cosine similarity of identical vectors should be 1.0', () {
      final v1 = [1.0, 0.0, -1.0, 0.5];
      final v2 = [1.0, 0.0, -1.0, 0.5];
      final sim = aiService.calculateCosineSimilarity(v1, v2);
      expect(sim, closeTo(1.0, 0.0001));
    });

    test('Cosine similarity of orthogonal vectors should be 0.0', () {
      final v1 = [1.0, 0.0, 0.0];
      final v2 = [0.0, 1.0, 0.0];
      final sim = aiService.calculateCosineSimilarity(v1, v2);
      expect(sim, closeTo(0.0, 0.0001));
    });

    test('Cosine similarity of opposite vectors should be -1.0', () {
      final v1 = [1.0, 2.0, 3.0];
      final v2 = [-1.0, -2.0, -3.0];
      final sim = aiService.calculateCosineSimilarity(v1, v2);
      expect(sim, closeTo(-1.0, 0.0001));
    });
  });

  group('Encryption Logic Tests', () {
    test('AES-256-CBC Encryption and Decryption roundtrip', () {
      final key = enc.Key.fromSecureRandom(32); // AES-256 key
      final iv = enc.IV.fromSecureRandom(16); // 16-byte IV
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final plainText = "My private thoughts and journal entry details.";
      final plainBytes = Uint8List.fromList(plainText.codeUnits);

      // Encrypt
      final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);
      
      // Decrypt
      final decryptedBytes = encrypter.decryptBytes(encrypted, iv: iv);
      final decryptedText = String.fromCharCodes(decryptedBytes);

      expect(decryptedText, equals(plainText));
    });
  });

  group('Model Serialization Tests', () {
    test('JournalEntry serialization and deserialization matches', () {
      final now = DateTime.now();
      final original = JournalEntry(
        id: 'test-id-123',
        timestamp: now,
        transcription: 'Hello world transcription text',
        audioFilePath: '/path/to/encrypted/audio.enc',
        waveformAmplitudes: [0.1, 0.2, 0.5, 0.8, 0.4],
        durationSeconds: 15.5,
        embedding: [0.01, 0.02, 0.03],
      );

      final map = original.toMap();
      final recreated = JournalEntry.fromMap(map);

      expect(recreated.id, equals(original.id));
      expect(recreated.timestamp.millisecondsSinceEpoch, equals(original.timestamp.millisecondsSinceEpoch));
      expect(recreated.transcription, equals(original.transcription));
      expect(recreated.audioFilePath, equals(original.audioFilePath));
      expect(recreated.waveformAmplitudes, equals(original.waveformAmplitudes));
      expect(recreated.durationSeconds, equals(original.durationSeconds));
      expect(recreated.embedding, equals(original.embedding));
    });
  });
}
