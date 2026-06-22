import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:scriberag/data/models/journal_entry.dart';
import 'package:scriberag/data/repositories/journal_repository.dart';
import 'package:scriberag/data/services/speech_service.dart';
import 'package:scriberag/data/services/storage_service.dart';

enum RecordingState { idle, recording, transcribing, saving }

class JournalViewModel extends ChangeNotifier {
  final JournalRepository _journalRepository;
  final SpeechService _speechService;
  final StorageService _storageService;
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<JournalEntry> _entries = [];
  RecordingState _recordingState = RecordingState.idle;
  
  // Recording states
  String _currentTempId = "";
  String _tempAudioPath = "";
  String _liveTranscription = "";
  List<double> _liveAmplitudes = [];
  double _currentAmplitude = 0.0;
  int _recordingDurationSeconds = 0;
  Timer? _recordingTimer;
  StreamSubscription? _amplitudeSubscription;

  // Playback states
  String? _activeEntryId;
  bool _isPlaying = false;
  Duration _playerPosition = Duration.zero;
  Duration _playerDuration = Duration.zero;
  
  // Strong reference to prevent the in-memory audio source from being garbage collected
  DecryptedAudioSource? _currentAudioSource;
  
  String? _lastTranscriptionError;
  
  // Subscriptions for player
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;

  JournalViewModel(
    this._journalRepository,
    this._speechService,
    this._storageService,
  ) {
    _loadEntries();
    _initPlayerListeners();
  }

  // Getters
  List<JournalEntry> get entries => _entries;
  RecordingState get recordingState => _recordingState;
  bool get isRecording => _recordingState == RecordingState.recording;
  String get liveTranscription => _liveTranscription;
  List<double> get liveAmplitudes => _liveAmplitudes;
  double get currentAmplitude => _currentAmplitude;
  int get recordingDurationSeconds => _recordingDurationSeconds;
  String? get lastTranscriptionError => _lastTranscriptionError;
  
  String? get activeEntryId => _activeEntryId;
  bool get isPlaying => _isPlaying;
  Duration get playerPosition => _playerPosition;
  Duration get playerDuration => _playerDuration;
  double get playbackProgress {
    if (_playerDuration.inMilliseconds == 0) return 0.0;
    return _playerPosition.inMilliseconds / _playerDuration.inMilliseconds;
  }

  void _loadEntries() {
    _entries = _journalRepository.getEntries();
    notifyListeners();
  }

  void updateLiveTranscription(String text) {
    _liveTranscription = text;
    notifyListeners();
  }

  void _initPlayerListeners() {
    _positionSubscription = _audioPlayer.positionStream.listen((pos) {
      _playerPosition = pos;
      notifyListeners();
    });

    _durationSubscription = _audioPlayer.durationStream.listen((dur) {
      _playerDuration = dur ?? Duration.zero;
      notifyListeners();
    });

    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _playerPosition = Duration.zero;
        _audioPlayer.pause();
        _audioPlayer.seek(Duration.zero);
      }
      notifyListeners();
    });
  }

  // Permission check helper
  Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  // Recording Controls
  Future<void> startRecording() async {
    if (_recordingState != RecordingState.idle) return;

    final hasPermission = await checkMicrophonePermission();
    if (!hasPermission) {
      throw Exception("Microphone permission is required to record journals.");
    }

    _recordingState = RecordingState.recording;
    _currentTempId = const Uuid().v4();
    _liveTranscription = "";
    _liveAmplitudes = [];
    _currentAmplitude = 0.0;
    _recordingDurationSeconds = 0;
    
    _tempAudioPath = await _storageService.getTempAudioPath(_currentTempId);

    try {
      // 1. Start audio recording with settings optimized for voice / speech-to-text
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          bitRate: 32000,
        ),
        path: _tempAudioPath,
      );

      // 2. Start recording timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingDurationSeconds++;
        notifyListeners();
      });

      // 3. Start recording amplitude stream
      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
            // Convert dB (typically -160 to 0) to a normalized value (0.0 to 1.0)
            final db = amp.current;
            double norm = 0.0;
            if (db > -120.0) {
              norm = (db + 120.0) / 120.0;
            }
            _currentAmplitude = norm.clamp(0.0, 1.0);
            _liveAmplitudes.add(_currentAmplitude);
            notifyListeners();
          });

      // 4. Start speech-to-text live listening (avoid starting it on Android due to exclusive mic lock conflict)
      if (!Platform.isAndroid) {
        try {
          await _speechService.startListening(
            onResult: (text) {
              _liveTranscription = text;
              notifyListeners();
            },
          );
        } catch (e) {
          print("Speech recognition failed to start: $e");
        }
      }

      notifyListeners();
    } catch (e) {
      _cleanupRecording();
      _recordingState = RecordingState.idle;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopRecordingAndSave() async {
    if (_recordingState != RecordingState.recording) return;

    _recordingState = RecordingState.transcribing;
    notifyListeners();

    // Stop duration timer and listeners
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    
    try {
      // Stop speech recognition
      await _speechService.stopListening();

      // Stop recorder to release microphone lock
      final path = await _audioRecorder.stop();
      
      if (path != null) {
        _recordingState = RecordingState.saving;
        notifyListeners();

        _lastTranscriptionError = null;
        // Get transcription: use live transcription if present, otherwise fallback to AI Service post-recording
        String finalTranscription = _liveTranscription.trim();
        if (finalTranscription.isEmpty) {
          try {
            final rawBytes = await File(_tempAudioPath).readAsBytes();
            finalTranscription = await _journalRepository.transcribeAudio(rawBytes);
          } catch (e) {
            print("Post-recording transcription failed: $e");
            String errStr = e.toString();
            if (errStr.contains("SocketException") || errStr.contains("Failed host lookup")) {
              _lastTranscriptionError = "Transcription failed: Network connection error. Unable to reach Google Gemini API.";
            } else {
              _lastTranscriptionError = "Transcription failed: $errStr";
            }
          }
        }

        // Use a descriptive placeholder if transcription is still empty
        if (finalTranscription.trim().isEmpty) {
          finalTranscription = "Voice Entry (${DateTime.now().toLocal().toString().substring(0, 16)})";
        }

        // If amplitudes is too small or empty, populate with dummy values
        if (_liveAmplitudes.isEmpty) {
          _liveAmplitudes = [0.1, 0.15, 0.25, 0.35, 0.2, 0.1, 0.05];
        }

        // Save entry
        await _journalRepository.addEntry(
          rawAudioPath: _tempAudioPath,
          transcription: finalTranscription,
          waveformAmplitudes: _liveAmplitudes,
          durationSeconds: _recordingDurationSeconds.toDouble(),
        );

        _loadEntries();
      }
    } catch (e) {
      print("Error saving journal entry: $e");
      rethrow;
    } finally {
      _cleanupRecording();
      _recordingState = RecordingState.idle;
      notifyListeners();
    }
  }

  Future<void> cancelRecording() async {
    if (_recordingState != RecordingState.recording) return;

    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    
    try {
      await _speechService.cancelListening();
      await _audioRecorder.stop();
      
      final file = File(_tempAudioPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print("Error cancelling recording: $e");
    } finally {
      _cleanupRecording();
      _recordingState = RecordingState.idle;
      notifyListeners();
    }
  }

  void _cleanupRecording() {
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _currentAmplitude = 0.0;
  }

  // Playback Controls
  Future<void> playEntry(JournalEntry entry) async {
    // If the selected entry is already loaded
    if (_activeEntryId == entry.id) {
      if (_isPlaying) {
        await pausePlayback();
      } else {
        await _audioPlayer.play();
      }
      return;
    }

    // Load new audio
    try {
      await stopPlayback();
      _activeEntryId = entry.id;
      notifyListeners();

      // Get decrypted bytes from repository
      final decryptedBytes = await _journalRepository.getDecryptedAudio(entry.id);
      
      // Load decrypted bytes in-memory source and keep a strong reference to prevent GC
      _currentAudioSource = DecryptedAudioSource(decryptedBytes);
      await _audioPlayer.setAudioSource(_currentAudioSource!);
      
      await _audioPlayer.play();
    } catch (e) {
      print("Error starting audio playback: $e");
      _activeEntryId = null;
      _currentAudioSource = null;
      notifyListeners();
    }
  }

  Future<void> pausePlayback() async {
    await _audioPlayer.pause();
    notifyListeners();
  }

  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
    _activeEntryId = null;
    _playerPosition = Duration.zero;
    _playerDuration = Duration.zero;
    _currentAudioSource = null;
    notifyListeners();
  }

  Future<void> seekPlayback(double percentage) async {
    if (_activeEntryId == null) return;
    final targetMs = (_playerDuration.inMilliseconds * percentage).round();
    await _audioPlayer.seek(Duration(milliseconds: targetMs));
  }

  // Delete Entry
  Future<void> deleteEntry(String id) async {
    if (_activeEntryId == id) {
      await stopPlayback();
    }
    await _journalRepository.deleteEntry(id);
    _loadEntries();
  }

  // DB wipe
  Future<void> wipeAllData() async {
    await stopPlayback();
    await _storageService.clearAll();
    _loadEntries();
  }

  @override
  void dispose() {
    _cleanupRecording();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _currentAudioSource = null;
    super.dispose();
  }
}

// In-Memory StreamAudioSource to feed decrypted bytes straight to just_audio
class DecryptedAudioSource extends StreamAudioSource {
  final List<int> bytes;
  final String contentType;

  DecryptedAudioSource(this.bytes, {this.contentType = 'audio/mp4'});

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final int start0 = start ?? 0;
    final int end0 = (end == null || end > bytes.length) ? bytes.length : end;
    
    // Ensure bounds are safe and valid
    final int actualStart = start0.clamp(0, bytes.length);
    final int actualEnd = end0.clamp(actualStart, bytes.length);
    
    final chunk = bytes.sublist(actualStart, actualEnd);

    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: chunk.length,
      offset: actualStart,
      stream: Stream.value(chunk),
      contentType: contentType,
    );
  }
}
