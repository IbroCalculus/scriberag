class JournalEntry {
  final String id;
  final DateTime timestamp;
  final String transcription;
  final String audioFilePath;
  final List<double> waveformAmplitudes;
  final double durationSeconds;
  final List<double>? embedding;

  JournalEntry({
    required this.id,
    required this.timestamp,
    required this.transcription,
    required this.audioFilePath,
    required this.waveformAmplitudes,
    required this.durationSeconds,
    this.embedding,
  });

  JournalEntry copyWith({
    String? id,
    DateTime? timestamp,
    String? transcription,
    String? audioFilePath,
    List<double>? waveformAmplitudes,
    double? durationSeconds,
    List<double>? embedding,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      transcription: transcription ?? this.transcription,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      waveformAmplitudes: waveformAmplitudes ?? this.waveformAmplitudes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      embedding: embedding ?? this.embedding,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'transcription': transcription,
      'audioFilePath': audioFilePath,
      'waveformAmplitudes': waveformAmplitudes,
      'durationSeconds': durationSeconds,
      'embedding': embedding,
    };
  }

  factory JournalEntry.fromMap(Map<dynamic, dynamic> map) {
    return JournalEntry(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      transcription: map['transcription'] as String,
      audioFilePath: map['audioFilePath'] as String,
      waveformAmplitudes: (map['waveformAmplitudes'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      durationSeconds: (map['durationSeconds'] as num?)?.toDouble() ?? 0.0,
      embedding: (map['embedding'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
    );
  }
}
