import 'package:scriberag/data/models/chat_message.dart';
import 'package:scriberag/data/services/storage_service.dart';
import 'package:uuid/uuid.dart';

class ChatRepository {
  final StorageService _storageService;
  final _uuid = const Uuid();

  ChatRepository(this._storageService);

  // Retrieve all chat messages
  List<ChatMessage> getMessages() {
    final box = _storageService.journalBox;
    final messages = <ChatMessage>[];
    for (var key in box.keys) {
      if (key is String && key.startsWith('chat_')) {
        final value = box.get(key);
        if (value is Map) {
          try {
            messages.add(ChatMessage.fromMap(value));
          } catch (e) {
            print("Error parsing chat message: $e");
          }
        }
      }
    }
    // Sort by timestamp ascending (chronological order)
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  // Add a new message
  Future<ChatMessage> addMessage(String text, MessageSender sender, {List<String>? matchedEntryIds}) async {
    final id = 'chat_${_uuid.v4()}';
    final message = ChatMessage(
      id: id,
      text: text,
      sender: sender,
      timestamp: DateTime.now(),
      matchedEntryIds: matchedEntryIds,
    );
    await _storageService.journalBox.put(id, message.toMap());
    return message;
  }

  // Clear chat history
  Future<void> clearHistory() async {
    final box = _storageService.journalBox;
    final chatKeys = box.keys.where((k) => k is String && k.startsWith('chat_')).toList();
    for (var key in chatKeys) {
      await box.delete(key);
    }
  }
}
