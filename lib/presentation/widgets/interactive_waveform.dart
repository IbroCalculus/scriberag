import 'package:flutter/material.dart';
import 'package:scriberag/presentation/widgets/waveform_painter.dart';

class InteractiveWaveform extends StatelessWidget {
  final List<double> amplitudes;
  final double progress; // between 0.0 and 1.0
  final Function(double percentage)? onSeek;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;

  const InteractiveWaveform({
    super.key,
    required this.amplitudes,
    required this.progress,
    this.onSeek,
    this.height = 60.0,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeColor ?? theme.colorScheme.primary;
    final inactive = inactiveColor ?? theme.colorScheme.primary.withValues(alpha: 0.2);

    return GestureDetector(
      onTapDown: (details) => _handleSeek(context, details.localPosition.dx),
      onHorizontalDragUpdate: (details) => _handleSeek(context, details.localPosition.dx),
      child: Container(
        height: height,
        width: double.infinity,
        color: Colors.transparent, // Ensures taps anywhere in the boundary are registered
        child: CustomPaint(
          painter: WaveformPainter(
            amplitudes: amplitudes,
            progress: progress.clamp(0.0, 1.0),
            activeColor: active,
            inactiveColor: inactive,
          ),
        ),
      ),
    );
  }

  void _handleSeek(BuildContext context, double localX) {
    if (onSeek == null) return;
    
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final width = renderBox.size.width;
    if (width <= 0) return;

    final percentage = (localX / width).clamp(0.0, 1.0);
    onSeek!(percentage);
  }
}
