import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final double barWidth;
  final double barGap;

  WaveformPainter({
    required this.amplitudes,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    this.barWidth = 3.0,
    this.barGap = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final centerY = size.height / 2;
    
    // Calculate how many bars can fit in the available width
    final maxBars = (size.width / (barWidth + barGap)).floor();
    if (maxBars <= 0) return;
    
    final int totalAmplitudes = amplitudes.length;
    
    // Step size to downsample/sample amplitudes to match available bar slots
    final double step = totalAmplitudes / maxBars;

    for (int i = 0; i < maxBars; i++) {
      final ampIndex = (i * step).floor().clamp(0, totalAmplitudes - 1);
      final amplitude = amplitudes[ampIndex]; // Value between 0.0 and 1.0

      // Calculate bar height. Set a minimum height of 4px so it looks continuous.
      final barHeight = (amplitude * size.height).clamp(4.0, size.height);

      final x = i * (barWidth + barGap) + barWidth / 2;
      final top = centerY - barHeight / 2;
      final bottom = centerY + barHeight / 2;

      // Determine if this bar has been played
      final isPlayed = (i / maxBars) <= progress;
      paint.color = isPlayed ? activeColor : inactiveColor;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - barWidth / 2, top, x + barWidth / 2, bottom),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes ||
        oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.barGap != barGap;
  }
}
