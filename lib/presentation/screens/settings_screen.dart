import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scriberag/data/services/ai_service.dart';
import 'package:scriberag/presentation/viewmodels/chat_viewmodel.dart';
import 'package:scriberag/presentation/viewmodels/journal_viewmodel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _geminiKeyController = TextEditingController();
  final _openaiKeyController = TextEditingController();
  final _anthropicKeyController = TextEditingController();
  final _lmStudioUrlController = TextEditingController();
  final _lmStudioModelController = TextEditingController();

  String _selectedProvider = 'gemini';
  bool _obscureKeys = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final aiService = context.read<AIService>();
    final geminiKey = await aiService.getGeminiKey();
    final openaiKey = await aiService.getOpenAIKey();
    final anthropicKey = await aiService.getAnthropicKey();
    
    setState(() {
      _selectedProvider = aiService.activeProvider;
      _geminiKeyController.text = geminiKey ?? '';
      _openaiKeyController.text = openaiKey ?? '';
      _anthropicKeyController.text = anthropicKey ?? '';
      _lmStudioUrlController.text = aiService.lmStudioUrl;
      _lmStudioModelController.text = aiService.lmStudioModel;
    });
  }

  @override
  void dispose() {
    _geminiKeyController.dispose();
    _openaiKeyController.dispose();
    _anthropicKeyController.dispose();
    _lmStudioUrlController.dispose();
    _lmStudioModelController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final aiService = context.read<AIService>();
    
    await aiService.saveActiveProvider(_selectedProvider);
    await aiService.saveGeminiKey(_geminiKeyController.text.trim());
    await aiService.saveOpenAIKey(_openaiKeyController.text.trim());
    await aiService.saveAnthropicKey(_anthropicKeyController.text.trim());
    await aiService.saveLmStudioUrl(_lmStudioUrlController.text.trim());
    await aiService.saveLmStudioModel(_lmStudioModelController.text.trim());

    if (mounted) {
      context.read<ChatViewModel>().notifyKeyChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI Configurations saved successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmWipeData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wipe All Data?'),
        content: const Text(
          'This will permanently delete all your voice journal entries, encrypted audio files, and chat memories. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wipe Data'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (mounted) {
        final journalVm = context.read<JournalViewModel>();
        final chatVm = context.read<ChatViewModel>();
        
        await journalVm.wipeAllData();
        await chatVm.clearHistory();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All journal data wiped successfully.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Selection Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Active AI Provider',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Choose the model provider for summarizing, reflecting, and answering questions about your journals.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedProvider,
                      decoration: const InputDecoration(
                        labelText: 'Select Provider',
                      ),
                      dropdownColor: theme.colorScheme.surface,
                      items: const [
                        DropdownMenuItem(
                          value: 'gemini',
                          child: Text(
                            'Google Gemini (1.5 Flash)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'openai',
                          child: Text(
                            'OpenAI (GPT-4o)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'anthropic',
                          child: Text(
                            'Anthropic (Claude 3.5 Sonnet)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'lm_studio',
                          child: Text(
                            'LM Studio (Offline Local LLM)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedProvider = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Provider Credentials Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.vpn_key_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'API Credentials',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            _obscureKeys ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureKeys = !_obscureKeys;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Gemini field (always needed for embeddings)
                    TextField(
                      controller: _geminiKeyController,
                      obscureText: _obscureKeys,
                      decoration: InputDecoration(
                        labelText: 'Gemini API Key (Required for Vector Embeddings)',
                        hintText: 'Enter Gemini API key',
                        suffixIcon: _geminiKeyController.text.isNotEmpty
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // OpenAI field (conditional highlight)
                    TextField(
                      controller: _openaiKeyController,
                      obscureText: _obscureKeys,
                      decoration: InputDecoration(
                        labelText: 'OpenAI API Key',
                        hintText: 'Enter OpenAI API key',
                        fillColor: _selectedProvider == 'openai'
                            ? theme.colorScheme.primary.withValues(alpha: 0.05)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Anthropic field (conditional highlight)
                    TextField(
                      controller: _anthropicKeyController,
                      obscureText: _obscureKeys,
                      decoration: InputDecoration(
                        labelText: 'Anthropic API Key',
                        hintText: 'Enter Anthropic API key',
                        fillColor: _selectedProvider == 'anthropic'
                            ? theme.colorScheme.primary.withValues(alpha: 0.05)
                            : null,
                      ),
                    ),
                    
                    // LM Studio configurations (shown only if lm_studio is active)
                    if (_selectedProvider == 'lm_studio') ...[
                      const SizedBox(height: 24),
                      Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'LM Studio Connection Settings',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _lmStudioUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Base URL',
                          hintText: 'http://localhost:1234/v1',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _lmStudioModelController,
                        decoration: const InputDecoration(
                          labelText: 'Model Name / ID',
                          hintText: 'e.g., local-model',
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saveSettings,
                        child: const Text(
                          'Save Configuration',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Privacy & Database Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security_rounded,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Privacy & Storage',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All your recordings, transcripts, and embeddings are stored locally using on-device AES-256 encryption. If you wipe the data, it is permanently destroyed.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _confirmWipeData,
                        icon: const Icon(Icons.delete_forever_rounded),
                        label: const Text(
                          'Wipe All App Data',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
