import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scriberag/core/theme.dart';
import 'package:scriberag/data/repositories/chat_repository.dart';
import 'package:scriberag/data/repositories/journal_repository.dart';
import 'package:scriberag/data/services/encryption_service.dart';
import 'package:scriberag/data/services/ai_service.dart';
import 'package:scriberag/data/services/speech_service.dart';
import 'package:scriberag/data/services/storage_service.dart';
import 'package:scriberag/presentation/screens/main_navigation.dart';
import 'package:scriberag/presentation/viewmodels/chat_viewmodel.dart';
import 'package:scriberag/presentation/viewmodels/journal_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Instantiate services
  final encryptionService = EncryptionService();
  final storageService = StorageService(encryptionService);
  final speechService = SpeechService();
  final aiService = AIService();

  // Initialize core services asynchronously
  await encryptionService.init();
  await storageService.init();
  await speechService.init();
  await aiService.init();

  // Instantiate repositories
  final journalRepository = JournalRepository(
    storageService,
    encryptionService,
    aiService,
  );
  final chatRepository = ChatRepository(storageService);

  runApp(
    MultiProvider(
      providers: [
        // Expose Services
        Provider<EncryptionService>.value(value: encryptionService),
        Provider<StorageService>.value(value: storageService),
        Provider<SpeechService>.value(value: speechService),
        Provider<AIService>.value(value: aiService),
        // Expose Repositories
        Provider<JournalRepository>.value(value: journalRepository),
        Provider<ChatRepository>.value(value: chatRepository),
        // Expose ViewModels
        ChangeNotifierProvider(
          create: (_) => JournalViewModel(
            journalRepository,
            speechService,
            storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatViewModel(
            chatRepository,
            journalRepository,
            aiService,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScribeRAG',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Defaulting to our premium deep space theme
      home: const MainNavigation(),
      debugShowCheckedModeBanner: false,
    );
  }
}
