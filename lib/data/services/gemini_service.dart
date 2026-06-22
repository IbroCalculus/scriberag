import 'dart:io' as io;
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:scriberag/core/constants.dart';
import 'package:scriberag/data/models/journal_entry.dart';

class GeminiService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  GenerativeModel? _chatModel;
  GenerativeModel? _embedModel;
  String? _apiKey;

  Future<void> init() async {
    _apiKey = await _secureStorage.read(
      key: AppConstants.geminiApiKeySecureKey,
    );
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      _initModels(_apiKey!);
    }
  }

  void _initModels(String apiKey) {
    _chatModel = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
    _embedModel = GenerativeModel(model: 'text-embedding-004', apiKey: apiKey);
  }

  Future<void> saveApiKey(String key) async {
    await _secureStorage.write(
      key: AppConstants.geminiApiKeySecureKey,
      value: key,
    );
    _apiKey = key;
    if (key.isNotEmpty) {
      _initModels(key);
    } else {
      _chatModel = null;
      _embedModel = null;
    }
  }

  Future<String?> getApiKey() async {
    return await _secureStorage.read(key: AppConstants.geminiApiKeySecureKey);
  }

  bool get hasApiKey => _chatModel != null;

  // Transcribe an audio file using Gemini Multimodal audio input
  Future<String> transcribeAudio(String filePath) async {
    if (!hasApiKey) {
      throw Exception("Gemini API Key is not set.");
    }

    final file = io.File(filePath);
    if (!await file.exists()) {
      throw Exception("Audio file not found for transcription.");
    }

    final audioBytes = await file.readAsBytes();

    final content = [
      Content.multi([
        // Audio encoder is aacLc (.m4a), which corresponds to audio/mp4 or audio/aac MIME type.
        DataPart('audio/mp4', audioBytes),
        TextPart(
          'Transcribe the spoken words in this audio file verbatim. Do not add introductory phrases, and do not explain. Just output the transcription text. If there is no speech, return an empty string.',
        ),
      ]),
    ];

    final response = await _chatModel!.generateContent(content);
    return response.text ?? "";
  }

  // Generate embeddings for a text string
  Future<List<double>> getEmbedding(String text) async {
    if (!hasApiKey) {
      throw Exception(
        "Gemini API Key is not set. Please go to Settings to configure it.",
      );
    }

    final response = await _embedModel!.embedContent(Content.text(text));
    final values = response.embedding.values;
    return values.map((e) => e.toDouble()).toList();
  }

  // Calculate cosine similarity between two vectors
  double calculateCosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length) return 0.0;
    double dotProduct = 0.0;
    double magnitudeV1 = 0.0;
    double magnitudeV2 = 0.0;

    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      magnitudeV1 += v1[i] * v1[i];
      magnitudeV2 += v2[i] * v2[i];
    }

    if (magnitudeV1 == 0.0 || magnitudeV2 == 0.0) return 0.0;
    return dotProduct / (sqrt(magnitudeV1) * sqrt(magnitudeV2));
  }

  // Search journal entries and return a stream of generated answers based on matching entries
  Stream<String> searchAndSynthesize(
    String query,
    List<JournalEntry> entries, {
    double minSimilarity = 0.35,
    int topK = 4,
  }) async* {
    if (!hasApiKey) {
      throw Exception("Gemini API Key is not set. Please go to Settings.");
    }

    if (entries.isEmpty) {
      yield "You don't have any journal entries yet! Record a voice entry first so I can retrieve context.";
      return;
    }

    // 1. Get embedding for the user query
    final queryEmbedding = await getEmbedding(query);

    // 2. Rank entries by cosine similarity
    final scoredEntries = entries.map((entry) {
      double score = 0.0;
      if (entry.embedding != null) {
        score = calculateCosineSimilarity(queryEmbedding, entry.embedding!);
      }
      return _ScoredEntry(entry, score);
    }).toList();

    // 3. Filter by similarity threshold and sort descending
    final matchingEntries = scoredEntries
        .where((element) => element.score >= minSimilarity)
        .toList();

    matchingEntries.sort((a, b) => b.score.compareTo(a.score));

    // Get the top K entries
    final topEntries = matchingEntries.take(topK).toList();

    if (topEntries.isEmpty) {
      yield "I searched your journal entries but couldn't find any relevant memories matching your query. Try asking about something else, or recording more entries!";
      return;
    }

    // 4. Construct context and prompt
    final contextBuffer = StringBuffer();
    contextBuffer.writeln(
      "Here are the most relevant journal entries matching the user's query:\n",
    );

    for (var i = 0; i < topEntries.length; i++) {
      final entry = topEntries[i].entry;
      final formattedDate = entry.timestamp.toLocal().toString().substring(
        0,
        16,
      );
      contextBuffer.writeln(
        "Entry #${i + 1} - Date: $formattedDate (Similarity Score: ${(topEntries[i].score * 100).toStringAsFixed(1)}%)",
      );
      contextBuffer.writeln("Transcription: \"${entry.transcription}\"");
      contextBuffer.writeln("-" * 40);
    }

    final prompt =
        """
You are ScribeRAG, a deeply empathetic and intelligent voice journaling AI companion. 
Your goal is to help the user reflect on their past journal entries and answer their questions using only the provided context.

Context:
${contextBuffer.toString()}

User Query: "$query"

Instructions:
1. Synthesize a coherent, concise, and helpful response.
2. Directly answer the user's question by referencing specific entries and their dates (e.g., "On June 20, you mentioned...").
3. Adopt a supportive, reflective, and conversational tone, as you are a journal assistant.
4. Speak in the first person ("I") and refer to the user in the second person ("you").
5. If the provided entries do not contain the answer, politely tell the user that you couldn't find that memory in their current entries. Do NOT make up facts.
""";

    // 5. Call Gemini generation stream
    final content = [Content.text(prompt)];
    final responseStream = _chatModel!.generateContentStream(content);

    await for (final chunk in responseStream) {
      final text = chunk.text;
      if (text != null) {
        yield text;
      }
    }
  }
}

class _ScoredEntry {
  final JournalEntry entry;
  final double score;

  _ScoredEntry(this.entry, this.score);
}
