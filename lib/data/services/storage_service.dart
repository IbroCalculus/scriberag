import 'dart:io';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scriberag/core/constants.dart';
import 'package:scriberag/data/services/encryption_service.dart';

class StorageService {
  final EncryptionService _encryptionService;
  Box? _journalBox;
  Directory? _audioDir;

  StorageService(this._encryptionService);

  Future<void> init() async {
    if (_journalBox != null) return;

    // Initialize Hive for Flutter
    await Hive.initFlutter();

    // Get the encryption key from EncryptionService
    final hiveKey = await _encryptionService.getHiveEncryptionKey();

    // Open the encrypted box
    _journalBox = await Hive.openBox(
      AppConstants.hiveJournalBoxName,
      encryptionCipher: HiveAesCipher(hiveKey),
    );

    // Setup audio storage directory
    final docDir = await getApplicationDocumentsDirectory();
    _audioDir = Directory('${docDir.path}/audio_entries');
    if (!await _audioDir!.exists()) {
      await _audioDir!.create(recursive: true);
    }
  }

  // Get the open box
  Box get journalBox {
    if (_journalBox == null) {
      throw Exception("StorageService must be initialized first");
    }
    return _journalBox!;
  }

  // Get a path to store a new raw audio file temporarily
  Future<String> getTempAudioPath(String id) async {
    final docDir = await getTemporaryDirectory();
    return '${docDir.path}/temp_$id.m4a';
  }

  // Get the path where the encrypted audio file should live
  String getEncryptedAudioPath(String id) {
    if (_audioDir == null) {
      throw Exception("StorageService must be initialized first");
    }
    return '${_audioDir!.path}/$id.enc';
  }

  // Check if encrypted audio file exists
  bool audioFileExists(String id) {
    final path = getEncryptedAudioPath(id);
    return File(path).existsSync();
  }

  // Delete encrypted audio file
  Future<void> deleteAudioFile(String id) async {
    final file = File(getEncryptedAudioPath(id));
    if (await file.exists()) {
      await file.delete();
    }
  }

  // Clear all data
  Future<void> clearAll() async {
    await journalBox.clear();
    if (_audioDir != null && await _audioDir!.exists()) {
      await _audioDir!.delete(recursive: true);
      await _audioDir!.create(recursive: true);
    }
  }
}
