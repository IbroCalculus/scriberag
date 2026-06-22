import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scriberag/data/models/journal_entry.dart';
import 'package:scriberag/presentation/viewmodels/journal_viewmodel.dart';
import 'package:scriberag/presentation/widgets/interactive_waveform.dart';

class JournalDetailScreen extends StatefulWidget {
  final JournalEntry entry;

  const JournalDetailScreen({super.key, required this.entry});

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  
  @override
  void deactivate() {
    // Stop playback if we navigate away from this screen
    context.read<JournalViewModel>().stopPlayback();
    super.deactivate();
  }

  String _formatDuration(Duration duration) {
    final mins = duration.inMinutes;
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.entry.transcription));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transcription copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final journalVm = context.watch<JournalViewModel>();
    
    final isCurrent = journalVm.activeEntryId == widget.entry.id;
    final isPlaying = isCurrent && journalVm.isPlaying;
    final currentPos = isCurrent ? journalVm.playerPosition : Duration.zero;
    final totalDur = isCurrent ? journalVm.playerDuration : Duration(seconds: widget.entry.durationSeconds.round());
    final progress = isCurrent ? journalVm.playbackProgress : 0.0;

    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(widget.entry.timestamp);
    final formattedTime = DateFormat('jm').format(widget.entry.timestamp);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete Entry',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Entry?'),
                  content: const Text('Are you sure you want to permanently delete this journal entry and its encrypted audio recording?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                if (mounted) {
                  await journalVm.deleteEntry(widget.entry.id);
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Text(
              formattedDate,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Recorded at $formattedTime',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onBackground.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),

            // Audio Player Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Interactive Waveform player
                    InteractiveWaveform(
                      amplitudes: widget.entry.waveformAmplitudes,
                      progress: progress,
                      onSeek: (pct) => journalVm.seekPlayback(pct),
                      height: 80,
                    ),
                    const SizedBox(height: 16),
                    // Timing details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(currentPos),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        Text(
                          _formatDuration(totalDur),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Player Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isCurrent)
                          IconButton(
                            icon: const Icon(Icons.stop_rounded),
                            iconSize: 32,
                            onPressed: () => journalVm.stopPlayback(),
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(20),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            try {
                              await journalVm.playEntry(widget.entry);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Playback failed: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 48), // spacer balance
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Transcript Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transcription',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  tooltip: 'Copy text',
                  onPressed: _copyToClipboard,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Transcript Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
              ),
              child: Text(
                widget.entry.transcription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Semantic status meta
            if (widget.entry.embedding != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.secondary.withOpacity(0.08),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: theme.colorScheme.secondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This entry is indexed and available for semantic memory searches.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
