import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/plugin.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:scriberag/core/constants.dart';
import 'package:scriberag/data/models/journal_entry.dart';

class AIService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Genkit? _ai;
  String _activeProvider = 'gemini';
  
  // Stored Keys/Configurations
  String? _geminiApiKey;
  String? _openaiApiKey;
  String? _anthropicApiKey;
  String _lmStudioBaseUrl = 'http://localhost:1234/v1';
  String _lmStudioModel = 'local-model';

  Future<void> init() async {
    _activeProvider = await _secureStorage.read(key: AppConstants.aiProviderSecureKey) ?? 'gemini';
    _geminiApiKey = await _secureStorage.read(key: AppConstants.geminiApiKeySecureKey);
    _openaiApiKey = await _secureStorage.read(key: AppConstants.openaiApiKeySecureKey);
    _anthropicApiKey = await _secureStorage.read(key: AppConstants.anthropicApiKeySecureKey);
    _lmStudioBaseUrl = await _secureStorage.read(key: AppConstants.lmStudioBaseUrlSecureKey) ?? 'http://localhost:1234/v1';
    _lmStudioModel = await _secureStorage.read(key: AppConstants.lmStudioModelSecureKey) ?? 'local-model';

    _initGenkit();
  }

  void _initGenkit() {
    final plugins = <GenkitPlugin>[];

    // Initialize only the plugins that have keys/configurations to avoid initialization crashes
    if (_geminiApiKey != null && _geminiApiKey!.isNotEmpty) {
      plugins.add(googleAI(apiKey: _geminiApiKey));
    }
    if (_openaiApiKey != null && _openaiApiKey!.isNotEmpty) {
      plugins.add(openAI(apiKey: _openaiApiKey));
    }
    if (_anthropicApiKey != null && _anthropicApiKey!.isNotEmpty) {
      plugins.add(anthropic(apiKey: _anthropicApiKey));
    }
    
    // LM Studio is local, so we register a secondary OpenAI plugin with its custom baseUrl and custom namespace
    plugins.add(openAI(
      name: 'lm-studio',
      apiKey: 'lm-studio-dummy-key',
      baseUrl: _lmStudioBaseUrl,
    ));

    _ai = Genkit(plugins: plugins);
  }

  // Configuration management
  Future<void> saveActiveProvider(String provider) async {
    await _secureStorage.write(key: AppConstants.aiProviderSecureKey, value: provider);
    _activeProvider = provider;
  }

  String get activeProvider => _activeProvider;

  Future<void> saveGeminiKey(String key) async {
    await _secureStorage.write(key: AppConstants.geminiApiKeySecureKey, value: key);
    _geminiApiKey = key;
    _initGenkit();
  }

  Future<String?> getGeminiKey() async => _geminiApiKey;

  Future<void> saveOpenAIKey(String key) async {
    await _secureStorage.write(key: AppConstants.openaiApiKeySecureKey, value: key);
    _openaiApiKey = key;
    _initGenkit();
  }

  Future<String?> getOpenAIKey() async => _openaiApiKey;

  Future<void> saveAnthropicKey(String key) async {
    await _secureStorage.write(key: AppConstants.anthropicApiKeySecureKey, value: key);
    _anthropicApiKey = key;
    _initGenkit();
  }

  Future<String?> getAnthropicKey() async => _anthropicApiKey;

  Future<void> saveLmStudioUrl(String url) async {
    await _secureStorage.write(key: AppConstants.lmStudioBaseUrlSecureKey, value: url);
    _lmStudioBaseUrl = url;
    _initGenkit();
  }

  String get lmStudioUrl => _lmStudioBaseUrl;

  Future<void> saveLmStudioModel(String model) async {
    await _secureStorage.write(key: AppConstants.lmStudioModelSecureKey, value: model);
    _lmStudioModel = model;
  }

  String get lmStudioModel => _lmStudioModel;

  // Test connection to LM Studio instance
  Future<bool> testLmStudioConnection(String url) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final cleanUrl = url.trim();
      final modelsEndpoint = cleanUrl.endsWith('/v1') ? '$cleanUrl/models' : '$cleanUrl/v1/models';
      final request = await client.getUrl(Uri.parse(modelsEndpoint));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Capabilities
  bool get hasEmbeddingCapability => _geminiApiKey != null && _geminiApiKey!.isNotEmpty;

  bool get hasChatCapability {
    switch (_activeProvider) {
      case 'gemini':
        return _geminiApiKey != null && _geminiApiKey!.isNotEmpty;
      case 'openai':
        return _openaiApiKey != null && _openaiApiKey!.isNotEmpty;
      case 'anthropic':
        return _anthropicApiKey != null && _anthropicApiKey!.isNotEmpty;
      case 'lm_studio':
        return _lmStudioBaseUrl.isNotEmpty;
      default:
        return false;
    }
  }

  // Generate embeddings (always using Gemini text-embedding-004 to keep vector space consistent)
  Future<List<double>> getEmbedding(String text) async {
    if (!hasEmbeddingCapability) {
      throw Exception("Gemini API Key is not set, which is required for vector embeddings.");
    }
    if (_ai == null) {
      throw Exception("AI Service is not initialized.");
    }

    final response = await _ai!.embedMany(
      documents: [
        DocumentData(content: [TextPart(text: text)]),
      ],
      embedder: googleAI.textEmbedding('text-embedding-004'),
    );

    if (response.isEmpty) {
      throw Exception("No embedding returned from Gemini.");
    }

    return response.first.embedding;
  }

  // Calculate cosine similarity
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

  // Get model reference for the active provider
  ModelRef _getActiveModel() {
    switch (_activeProvider) {
      case 'openai':
        return openAI.model('gpt-4o');
      case 'anthropic':
        return anthropic.model('claude-3-5-sonnet');
      case 'lm_studio':
        // Custom OpenAI-compatible namespace is 'lm-studio'
        return openAI.model(_lmStudioModel, namespace: 'lm-studio');
      case 'gemini':
      default:
        return googleAI.gemini('gemini-1.5-flash');
    }
  }

  // Search and Synthesize memories (RAG)
  Stream<String> searchAndSynthesize(
    String query,
    List<JournalEntry> entries, {
    double minSimilarity = 0.35,
    int topK = 4,
  }) async* {
    if (!hasChatCapability) {
      throw Exception("The selected AI Provider ($_activeProvider) is not configured.");
    }

    if (entries.isEmpty) {
      yield "You don't have any journal entries yet! Record a voice entry first so I can retrieve context.";
      return;
    }

    List<JournalEntry> matchingEntriesList = [];

    if (hasEmbeddingCapability) {
      try {
        // 1. Get embedding for the user query (Gemini)
        final queryEmbedding = await getEmbedding(query);

        // 2. Rank entries by cosine similarity
        final scoredEntries = entries.map((entry) {
          double score = 0.0;
          if (entry.embedding != null) {
            score = calculateCosineSimilarity(queryEmbedding, entry.embedding!);
          }
          return _ScoredEntry(entry, score);
        }).toList();

        // 3. Filter and sort
        final matchingEntries = scoredEntries
            .where((element) => element.score >= minSimilarity)
            .toList();

        matchingEntries.sort((a, b) => b.score.compareTo(a.score));
        matchingEntriesList = matchingEntries.take(topK).map((e) => e.entry).toList();
      } catch (e) {
        print("Embedding generation failed, falling back to text-based search: $e");
      }
    }

    // Keyword search fallback if embeddings are not available or embedding request failed
    if (matchingEntriesList.isEmpty) {
      final queryLower = query.toLowerCase();
      final queryWords = queryLower.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
      final scoredEntries = <_ScoredEntry>[];

      for (var entry in entries) {
        final textLower = entry.transcription.toLowerCase();
        double score = 0.0;

        if (queryWords.isEmpty) {
          if (textLower.contains(queryLower)) {
            score = 1.0;
          }
        } else {
          int matchCount = 0;
          for (var word in queryWords) {
            if (textLower.contains(word)) {
              matchCount++;
            }
          }
          score = matchCount / queryWords.length;
        }

        if (score > 0.0) {
          scoredEntries.add(_ScoredEntry(entry, score));
        }
      }

      scoredEntries.sort((a, b) => b.score.compareTo(a.score));
      matchingEntriesList = scoredEntries.take(topK).map((e) => e.entry).toList();
    }

    if (matchingEntriesList.isEmpty) {
      yield "I searched your journal entries but couldn't find any relevant memories matching your query. Try asking about something else, or recording more entries!";
      return;
    }

    // 4. Construct context and prompt
    final contextBuffer = StringBuffer();
    contextBuffer.writeln(
      "Here are the most relevant journal entries matching the user's query:\n",
    );

    for (var i = 0; i < matchingEntriesList.length; i++) {
      final entry = matchingEntriesList[i];
      final formattedDate = entry.timestamp.toLocal().toString().substring(0, 16);
      contextBuffer.writeln(
        "Entry #${i + 1} - Date: $formattedDate",
      );
      contextBuffer.writeln("Transcription: \"${entry.transcription}\"");
      contextBuffer.writeln("-" * 40);
    }

    final prompt = """
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

    // 5. Call Genkit generation stream
    final modelRef = _getActiveModel();
    final responseStream = _ai!.generateStream(
      model: modelRef,
      prompt: prompt,
    );

    await for (final chunk in responseStream) {
      yield chunk.text;
    }
  }

  // Transcribe audio using Gemini 1.5 Flash (which is always configured for embeddings)
  Future<String> transcribeAudio(List<int> audioBytes) async {
    if (!hasEmbeddingCapability) {
      throw Exception("Gemini API Key is not set, which is required for transcription.");
    }
    if (_ai == null) {
      throw Exception("AI Service is not initialized.");
    }

    final base64String = base64.encode(audioBytes);
    final dataUrl = 'data:audio/mp4;base64,$base64String';

    final message = Message(
      role: Role.user,
      content: [
        TextPart(text: 'Please transcribe the following audio file. Return ONLY the transcribed text, with no extra commentary, introductory text, or formatting. If the audio is silent or unintelligible, return an empty string.'),
        MediaPart(
          media: Media(
            url: dataUrl,
            contentType: 'audio/mp4',
          ),
        ),
      ],
    );

    final response = await _ai!.generate(
      model: googleAI.gemini('gemini-1.5-flash'),
      messages: [message],
    );

    return response.text.trim();
  }
}

class _ScoredEntry {
  final JournalEntry entry;
  final double score;

  _ScoredEntry(this.entry, this.score);
}
