import 'package:flutter/material.dart';

class RecordingControl extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onTap;
  final double currentAmplitude; // 0.0 to 1.0 (normalized amplitude)
  final String statusText;

  const RecordingControl({
    super.key,
    required this.isRecording,
    required this.onTap,
    required this.currentAmplitude,
    this.statusText = "",
  });

  @override
  State<RecordingControl> createState() => _RecordingControlState();
}

class _RecordingControlState extends State<RecordingControl> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant RecordingControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        // Compute dynamic pulse scaling factors based on recording status and amplitude
        final pulseFactor = widget.isRecording 
            ? 1.0 + (widget.currentAmplitude * 0.4) + (_pulseController.value * 0.1)
            : 1.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: widget.onTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glowing backdrop layers
                  if (widget.isRecording) ...[
                    Container(
                      width: 90 * pulseFactor,
                      height: 90 * pulseFactor,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.error.withOpacity(0.15),
                      ),
                    ),
                    Container(
                      width: 110 * pulseFactor,
                      height: 110 * pulseFactor,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.error.withOpacity(0.06),
                      ),
                    ),
                  ],
                  // Main trigger button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: widget.isRecording
                            ? [theme.colorScheme.error, const Color(0xFFFF5252)]
                            : [theme.colorScheme.primary, theme.colorScheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isRecording ? theme.colorScheme.error : theme.colorScheme.primary)
                              .withOpacity(0.4),
                          blurRadius: widget.isRecording ? 16 + (widget.currentAmplitude * 12) : 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (widget.statusText.isNotEmpty)
              Text(
                widget.statusText,
                style: TextStyle(
                  color: widget.isRecording ? theme.colorScheme.error : theme.colorScheme.onBackground.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
          ],
        );
      },
    );
  }
}
