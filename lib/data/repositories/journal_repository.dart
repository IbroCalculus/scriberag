import 'package:scriberag/data/models/journal_entry.dart';
import 'package:scriberag/data/services/storage_service.dart';
import 'package:scriberag/data/services/encryption_service.dart';
import 'package:scriberag/data/services/ai_service.dart';
import 'package:uuid/uuid.dart';

class JournalRepository {
  final StorageService _storageService;
  final EncryptionService _encryptionService;
  final AIService _aiService;
  final _uuid = const Uuid();

  JournalRepository(
    this._storageService,
    this._encryptionService,
    this._aiService,
  );

  // Retrieve all entries
  List<JournalEntry> getEntries() {
    final box = _storageService.journalBox;
    final entries = <JournalEntry>[];
    for (var key in box.keys) {
      // Exclude chat message keys
      if (key is String && !key.startsWith('chat_')) {
        final value = box.get(key);
        if (value is Map) {
          try {
            entries.add(JournalEntry.fromMap(value));
          } catch (e) {
            print("Error parsing journal entry: $e");
          }
        }
      }
    }
    // Sort by timestamp descending (newest first)
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  // Add new entry
  Future<JournalEntry> addEntry({
    required String rawAudioPath,
    required String transcription,
    required List<double> waveformAmplitudes,
    required double durationSeconds,
  }) async {
    final id = _uuid.v4();
    final timestamp = DateTime.now();
    final encryptedAudioPath = _storageService.getEncryptedAudioPath(id);

    // 1. Encrypt raw audio file and save it
    await _encryptionService.encryptFile(rawAudioPath, encryptedAudioPath);

    // 2. Generate embedding (if Gemini is configured)
    List<double>? embedding;
    if (_aiService.hasEmbeddingCapability && transcription.trim().isNotEmpty) {
      try {
        embedding = await _aiService.getEmbedding(transcription);
      } catch (e) {
        print("Failed to generate embedding: $e. Entry will be saved without embedding.");
      }
    }

    // 3. Create entry
    final entry = JournalEntry(
      id: id,
      timestamp: timestamp,
      transcription: transcription,
      audioFilePath: encryptedAudioPath,
      waveformAmplitudes: waveformAmplitudes,
      durationSeconds: durationSeconds,
      embedding: embedding,
    );

    // 4. Save to Hive Box
    await _storageService.journalBox.put(id, entry.toMap());

    return entry;
  }

  // Delete entry
  Future<void> deleteEntry(String id) async {
    await _storageService.journalBox.delete(id);
    await _storageService.deleteAudioFile(id);
  }

  // Decrypt audio file to memory bytes for player
  Future<List<int>> getDecryptedAudio(String id) async {
    final encryptedAudioPath = _storageService.getEncryptedAudioPath(id);
    return await _encryptionService.decryptFileToBytes(encryptedAudioPath);
  }

  // Transcribe audio using AI Service
  Future<String> transcribeAudio(List<int> audioBytes) async {
    return await _aiService.transcribeAudio(audioBytes);
  }

  bool get hasEmbeddingCapability => _aiService.hasEmbeddingCapability;

  // Re-generate missing embeddings (e.g. when API key was missing or failed during save)
  Future<void> regenerateEmbeddings() async {
    if (!_aiService.hasEmbeddingCapability) return;
    
    final box = _storageService.journalBox;
    for (var key in box.keys) {
      if (key is String && !key.startsWith('chat_')) {
        final value = box.get(key);
        if (value is Map) {
          final entry = JournalEntry.fromMap(value);
          if (entry.embedding == null && entry.transcription.trim().isNotEmpty) {
            try {
              final embedding = await _aiService.getEmbedding(entry.transcription);
              final updatedEntry = entry.copyWith(embedding: embedding);
              await box.put(key, updatedEntry.toMap());
            } catch (e) {
              print("Failed to generate embedding for entry ${entry.id}: $e");
            }
          }
        }
      }
    }
  }
}
