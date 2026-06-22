import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scriberag/data/models/journal_entry.dart';
import 'package:scriberag/presentation/screens/journal_detail_screen.dart';
import 'package:scriberag/presentation/viewmodels/journal_viewmodel.dart';
import 'package:scriberag/presentation/widgets/recording_control.dart';

class JournalListScreen extends StatelessWidget {
  const JournalListScreen({super.key});

  void _showRecordingBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const RecordingBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final journalVm = context.watch<JournalViewModel>();
    final entries = journalVm.entries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Scribe'),
      ),
      body: entries.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _buildEntryCard(context, theme, entry, journalVm);
              },
            ),
      floatingActionButton: FloatingActionButton.large(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showRecordingBottomSheet(context),
        child: const Icon(Icons.mic_none_rounded, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.mic_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Journals Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the microphone below to record your first encrypted voice journal entry.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    ThemeData theme,
    JournalEntry entry,
    JournalViewModel journalVm,
  ) {
    final formattedDate = DateFormat('EEEE, MMM d, yyyy').format(entry.timestamp);
    final formattedTime = DateFormat('jm').format(entry.timestamp);
    final durationMin = (entry.durationSeconds / 60).floor();
    final durationSec = (entry.durationSeconds % 60).round().toString().padLeft(2, '0');

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) {
        journalVm.deleteEntry(entry.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal entry deleted')),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  formattedTime,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  entry.transcription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.audiotrack_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$durationMin:$durationSec',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (entry.embedding != null) ...[
                      Icon(
                        Icons.insights_rounded,
                        size: 14,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Indexed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JournalDetailScreen(entry: entry),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class RecordingBottomSheet extends StatefulWidget {
  const RecordingBottomSheet({super.key});

  @override
  State<RecordingBottomSheet> createState() => _RecordingBottomSheetState();
}

class _RecordingBottomSheetState extends State<RecordingBottomSheet> {
  late TextEditingController _transcriptionController;
  late JournalViewModel _journalVm;

  @override
  void initState() {
    super.initState();
    _transcriptionController = TextEditingController();
    
    // Auto start recording when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _journalVm = context.read<JournalViewModel>();
      _journalVm.addListener(_onViewModelChanged);
      _journalVm.startRecording().catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
          Navigator.pop(context);
        }
      });
    });
  }

  void _onViewModelChanged() {
    if (mounted) {
      if (_transcriptionController.text != _journalVm.liveTranscription) {
        _transcriptionController.text = _journalVm.liveTranscription;
      }
    }
  }

  @override
  void dispose() {
    _journalVm.removeListener(_onViewModelChanged);
    _transcriptionController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSecs) {
    final mins = (totalSecs / 60).floor();
    final secs = (totalSecs % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final journalVm = context.watch<JournalViewModel>();

    String statusText = "Listening...";
    if (journalVm.recordingState == RecordingState.transcribing) {
      statusText = "Finalizing Transcription...";
    } else if (journalVm.recordingState == RecordingState.saving) {
      statusText = "Encrypting and Saving Local File...";
    }

    return Container(
      padding: EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 24.0,
        bottom: 24.0 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _formatDuration(journalVm.recordingDurationSeconds),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          
          // Transcription Live Preview Container (Manually Editable)
          Container(
            width: double.infinity,
            height: 120,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
            ),
            child: TextField(
              controller: _transcriptionController,
              maxLines: null,
              onChanged: (text) => journalVm.updateLiveTranscription(text),
              decoration: const InputDecoration(
                hintText: 'Start speaking to see transcription, or type here...',
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Glowing pulsator record button or progress spinner
          if (journalVm.recordingState == RecordingState.transcribing ||
              journalVm.recordingState == RecordingState.saving) ...[
            Container(
              height: 110,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    statusText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            RecordingControl(
              isRecording: journalVm.isRecording,
              currentAmplitude: journalVm.currentAmplitude,
              statusText: statusText,
              onTap: () async {
                if (journalVm.isRecording) {
                  try {
                    await journalVm.stopRecordingAndSave();
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Saving failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
          const SizedBox(height: 20),

          // Cancel button
          if (journalVm.isRecording)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              onPressed: () async {
                await journalVm.cancelRecording();
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Cancel & Discard'),
            ),
        ],
      ),
    ),
  );
  }
}
