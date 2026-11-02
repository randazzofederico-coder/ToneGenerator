import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Compact rotary knob widget with double-tap to reset.
/// Accepts [diameter] for scalable sizing.
class MiniKnob extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double resetValue;
  final Color color;
  final String label;
  final String Function(double value) displayValue;
  final ValueChanged<double> onChanged;
  final double diameter;

  const MiniKnob({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    required this.resetValue,
    required this.color,
    required this.label,
    required this.displayValue,
    required this.onChanged,
    this.diameter = 26,
  });

  @override
  State<MiniKnob> createState() => _MiniKnobState();
}

class _MiniKnobState extends State<MiniKnob> {
  double _dragStartY = 0;
  double _dragStartValue = 0;

  @override
  Widget build(BuildContext context) {
    final normalized = ((widget.value - widget.min) / (widget.max - widget.min))
        .clamp(0.0, 1.0);
    final d = widget.diameter;

    return GestureDetector(
      onDoubleTap: () => widget.onChanged(widget.resetValue),
      onVerticalDragStart: (details) {
        _dragStartY = details.globalPosition.dy;
        _dragStartValue = widget.value;
      },
      onVerticalDragUpdate: (details) {
        final delta = _dragStartY - details.globalPosition.dy;
        final range = widget.max - widget.min;
        final newValue = (_dragStartValue + delta / 180.0 * range).clamp(
          widget.min,
          widget.max,
        );
        widget.onChanged(newValue);
      },
      child: SizedBox(
        width: d + 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 8,
                color: Colors.white.withValues(alpha: 0.35),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(
              width: d,
              height: d,
              child: CustomPaint(
                painter: _KnobPainter(
                  normalized: normalized,
                  color: widget.color,
                ),
              ),
            ),
            Text(
              widget.displayValue(widget.value),
              style: TextStyle(
                fontSize: 8,
                color: Colors.white.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  final double normalized;
  final Color color;

  _KnobPainter({required this.normalized, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Background track arc
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const startAngle = 135.0 * math.pi / 180;
    const sweepAngle = 270.0 * math.pi / 180;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Active arc
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final activeSweep = sweepAngle * normalized;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      activeSweep,
      false,
      activePaint,
    );

    // Glow effect at the indicator point
    final indicatorAngle = startAngle + activeSweep;
    final glowCenter = Offset(
      center.dx + radius * math.cos(indicatorAngle),
      center.dy + radius * math.sin(indicatorAngle),
    );
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(glowCenter, 3, glowPaint);

    // Center dot
    canvas.drawCircle(
      center,
      1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );

    // Indicator line
    final lineEnd = Offset(
      center.dx + (radius - 1) * math.cos(indicatorAngle),
      center.dy + (radius - 1) * math.sin(indicatorAngle),
    );
    final lineStart = Offset(
      center.dx + 3.5 * math.cos(indicatorAngle),
      center.dy + 3.5 * math.sin(indicatorAngle),
    );

    canvas.drawLine(
      lineStart,
      lineEnd,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) =>
      old.normalized != normalized || old.color != color;
}
