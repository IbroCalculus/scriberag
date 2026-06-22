import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scriberag/data/models/chat_message.dart';
import 'package:scriberag/data/repositories/chat_repository.dart';
import 'package:scriberag/data/repositories/journal_repository.dart';
import 'package:scriberag/data/services/ai_service.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatRepository _chatRepository;
  final JournalRepository _journalRepository;
  final AIService _aiService;

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _currentAiStreamText = "";

  ChatViewModel(
    this._chatRepository,
    this._journalRepository,
    this._aiService,
  ) {
    _loadMessages();
  }

  // Getters
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isAiConfigured => _aiService.hasChatCapability;
  String get currentAiStreamText => _currentAiStreamText;

  void _loadMessages() {
    _messages = _chatRepository.getMessages();
    notifyListeners();
  }

  // Trigger search and synthesis chat
  Future<void> sendQuery(String query) async {
    if (query.trim().isEmpty) return;
    if (!isAiConfigured) {
      throw Exception("The selected AI Provider is not configured. Please go to Settings to configure it.");
    }

    _isLoading = true;
    notifyListeners();

    // 1. Add User Message
    final userMsg = await _chatRepository.addMessage(query, MessageSender.user);
    _messages.add(userMsg);
    
    // 2. Set up initial streaming message
    _currentAiStreamText = "";
    final tempAiMessage = ChatMessage(
      id: "temp_ai_msg",
      text: "Searching memories...",
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
    );
    _messages.add(tempAiMessage);
    notifyListeners();

    try {
      // 3. Get all journal entries for RAG search
      final entries = _journalRepository.getEntries();
      
      // 4. Run retrieval and synthesis stream
      final responseStream = _aiService.searchAndSynthesize(query, entries);
      
      bool isFirstChunk = true;
      await for (final chunk in responseStream) {
        if (isFirstChunk) {
          _currentAiStreamText = "";
          isFirstChunk = false;
        }
        _currentAiStreamText += chunk;
        
        // Update the temp message inside the display list
        final index = _messages.indexWhere((m) => m.id == "temp_ai_msg");
        if (index != -1) {
          _messages[index] = ChatMessage(
            id: "temp_ai_msg",
            text: _currentAiStreamText,
            sender: MessageSender.ai,
            timestamp: DateTime.now(),
          );
        }
        notifyListeners();
      }

      // Remove the temporary message from the list
      _messages.removeWhere((m) => m.id == "temp_ai_msg");

      // Save the final synthesized response to persistence
      final finalAiMsg = await _chatRepository.addMessage(
        _currentAiStreamText,
        MessageSender.ai,
      );
      _messages.add(finalAiMsg);
    } catch (e) {
      print("RAG Error: $e");
      
      _messages.removeWhere((m) => m.id == "temp_ai_msg");
      final errorMsg = await _chatRepository.addMessage(
        "Sorry, I ran into an error while accessing your journal memories: ${e.toString()}",
        MessageSender.ai,
      );
      _messages.add(errorMsg);
    } finally {
      _isLoading = false;
      _currentAiStreamText = "";
      notifyListeners();
    }
  }

  // Clear history
  Future<void> clearHistory() async {
    await _chatRepository.clearHistory();
    _loadMessages();
  }

  // Handle setting updates (allows View to reload key configuration)
  void notifyKeyChanged() {
    notifyListeners();
  }
}
