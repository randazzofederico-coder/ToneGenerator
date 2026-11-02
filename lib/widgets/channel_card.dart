import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/channel_model.dart';
import '../providers/tone_generator_provider.dart';
import '../services/session_actions.dart';
import '../theme/ui_scale.dart';
import 'mini_knob.dart';

const _waveformLabels = ['Senoidal', 'Cuadrada', 'Triangular', 'Sierra'];

// ════════════════════════════════════════════════════════════════
//  ChannelCard — single unified layout
//
//  ┌─┬────────────────────────────────────────────────────────┐
//  │▌│ ●1  ~A4   [  440.0 Hz ↕]   ∿▾    M  S  Ø        ×   │
//  │▌│ 🎛PAN  🎛VOL     ×½ ═════slider══════ ×2             │
//  └─┴────────────────────────────────────────────────────────┘
// ════════════════════════════════════════════════════════════════

class ChannelCard extends StatelessWidget {
  final ToneChannel channel;
  final int channelIndex;
  final UIScale scale;

  const ChannelCard({
    super.key,
    required this.channel,
    required this.channelIndex,
    this.scale = defaultUIScale,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ToneGeneratorProvider>();
    final isSelected = context.select<ToneGeneratorProvider, bool>(
      (p) => p.selectedChannelId == channel.id,
    );
    final color = channelColor(channelIndex);

    return GestureDetector(
      onTap: () => provider.selectChannel(channel.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF141425),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Accent strip ──
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [color, color.withValues(alpha: 0.3)],
                    ),
                  ),
                ),
                // ── Content ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── ROW 1: Identity + toggles ──
                        _IdentityRow(
                          ch: channel,
                          index: channelIndex,
                          color: color,
                          provider: provider,
                        ),
                        const SizedBox(height: 6),
                        // ── ROW 2: Knobs + Slider ──
                        _ControlsRow(
                          ch: channel,
                          color: color,
                          provider: provider,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Row 1 — Identity: badge, note, freq, waveform, M/S/Ø, delete
// ════════════════════════════════════════════════════════════════

class _IdentityRow extends StatelessWidget {
  final ToneChannel ch;
  final int index;
  final Color color;
  final ToneGeneratorProvider provider;

  const _IdentityRow({
    required this.ch,
    required this.index,
    required this.color,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final displayNote = ToneChannel.displayNoteName(ch.frequency);

    return Row(
      children: [
        // Badge
        _Badge(index: index, color: color, muted: ch.muted),
        const SizedBox(width: 6),
        // Note name
        _NoteLabel(note: displayNote, muted: ch.muted),
        const SizedBox(width: 4),
        // Frequency (editable)
        _FrequencyDisplay(ch: ch, provider: provider, color: color),
        const SizedBox(width: 6),
        // Waveform selector
        _WaveformDropdown(
          waveform: ch.waveform,
          onChanged: (wf) => provider.setWaveform(ch.id, wf),
        ),
        const Spacer(),
        // Toggle chips
        _ToggleChip(
          label: 'M',
          active: ch.muted,
          activeColor: const Color(0xFFE94560),
          onTap: () => provider.toggleMute(ch.id),
        ),
        const SizedBox(width: 3),
        _ToggleChip(
          label: 'S',
          active: ch.solo,
          activeColor: const Color(0xFFFFD700),
          onTap: () => provider.toggleSolo(ch.id),
        ),
        const SizedBox(width: 3),
        _ToggleChip(
          label: 'Ø',
          active: ch.phaseInvert,
          activeColor: const Color(0xFFFF9800),
          onTap: () => provider.togglePhaseInvert(ch.id),
        ),
        const SizedBox(width: 6),
        // Delete
        _DeleteButton(onTap: () => removeChannelWithUndo(context, ch.id)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Row 2 — Controls: knobs + frequency slider
// ════════════════════════════════════════════════════════════════

class _ControlsRow extends StatelessWidget {
  final ToneChannel ch;
  final Color color;
  final ToneGeneratorProvider provider;

  const _ControlsRow({
    required this.ch,
    required this.color,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // PAN knob
        MiniKnob(
          value: ch.pan,
          min: -1.0,
          max: 1.0,
          resetValue: 0.0,
          diameter: 24,
          color: const Color(0xFFFF9800),
          label: 'PAN',
          displayValue: (v) => v.abs() < 0.01
              ? 'C'
              : v < 0
                  ? 'L${(-v * 100).round()}'
                  : 'R${(v * 100).round()}',
          onChanged: (v) => provider.setPan(ch.id, v),
        ),
        // VOL knob
        MiniKnob(
          value: ch.volume,
          min: 0.0,
          max: 1.0,
          resetValue: 0.3,
          diameter: 24,
          color: const Color(0xFF00D2FF),
          label: 'VOL',
          displayValue: (v) => '${(v * 100).round()}%',
          onChanged: (v) => provider.setVolume(ch.id, v),
        ),
        const SizedBox(width: 2),
        // Octave down
        _OctaveButton(
          label: '×½',
          onTap: () => provider.setFrequency(
            ch.id,
            (ch.frequency / 2).clamp(1.0, 20154.0),
          ),
        ),
        // Frequency slider
        Expanded(child: _FrequencySlider(ch: ch, color: color, provider: provider)),
        // Octave up
        _OctaveButton(
          label: '×2',
          onTap: () => provider.setFrequency(
            ch.id,
            (ch.frequency * 2).clamp(1.0, 20154.0),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Frequency slider (logarithmic)
// ════════════════════════════════════════════════════════════════

class _FrequencySlider extends StatelessWidget {
  final ToneChannel ch;
  final Color color;
  final ToneGeneratorProvider provider;

  const _FrequencySlider({
    required this.ch,
    required this.color,
    required this.provider,
  });

  static const double _minHz = 1.0;
  static const double _maxHz = 20154.0;

  @override
  Widget build(BuildContext context) {
    final logMin = math.log(_minHz) / math.ln10;
    final logMax = math.log(_maxHz) / math.ln10;
    final logRange = logMax - logMin;

    double freqToSlider(double f) {
      if (f <= _minHz) return 0.0;
      if (f >= _maxHz) return 1.0;
      return (math.log(f) / math.ln10 - logMin) / logRange;
    }

    double sliderToFreq(double p) =>
        math.pow(10, p * logRange + logMin).toDouble();

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: color.withValues(alpha: 0.6),
        inactiveTrackColor: Colors.white.withValues(alpha: 0.05),
        thumbColor: Colors.white,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      ),
      child: Slider(
        value: freqToSlider(ch.frequency),
        onChanged: (v) => provider.setFrequency(ch.id, sliderToFreq(v)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Building blocks
// ════════════════════════════════════════════════════════════════

/// Channel number badge
class _Badge extends StatelessWidget {
  final int index;
  final Color color;
  final bool muted;

  const _Badge({
    required this.index,
    required this.color,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: muted ? 0.3 : 1.0),
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Note name label (fixed width so layout doesn't shift)
class _NoteLabel extends StatelessWidget {
  final String note;
  final bool muted;

  const _NoteLabel({required this.note, required this.muted});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Text(
        note,
        style: TextStyle(
          color: muted ? Colors.white24 : Colors.white.withValues(alpha: 0.85),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Frequency display with vertical drag + double-tap editor
class _FrequencyDisplay extends StatefulWidget {
  final ToneChannel ch;
  final ToneGeneratorProvider provider;
  final Color color;

  const _FrequencyDisplay({
    required this.ch,
    required this.provider,
    required this.color,
  });

  @override
  State<_FrequencyDisplay> createState() => _FrequencyDisplayState();
}

class _FrequencyDisplayState extends State<_FrequencyDisplay> {
  double _dragStartY = 0;
  double _dragStartFreq = 0;

  @override
  Widget build(BuildContext context) {
    final ch = widget.ch;
    final color = widget.color;

    return GestureDetector(
      onDoubleTap: () => _showEditor(context),
      onVerticalDragStart: (d) {
        _dragStartY = d.globalPosition.dy;
        _dragStartFreq = ch.frequency;
      },
      onVerticalDragUpdate: (d) {
        final delta = _dragStartY - d.globalPosition.dy;
        final newFreq = (_dragStartFreq + delta * 0.1).clamp(1.0, 20154.0);
        widget.provider.setFrequency(ch.id, newFreq);
      },
      child: Container(
        width: 86,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                ch.frequency.toStringAsFixed(ch.frequency < 100 ? 2 : 1),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: ch.muted ? Colors.white24 : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              'Hz',
              style: TextStyle(
                fontSize: 8,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            Icon(
              Icons.swap_vert,
              size: 8,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditor(BuildContext context) {
    final ch = widget.ch;
    final color = widget.color;
    final controller = TextEditingController(
      text: ch.frequency.toStringAsFixed(ch.frequency < 100 ? 2 : 1),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Frecuencia (Hz)',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: '1 − 20154',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
            suffixText: 'Hz',
            suffixStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: color),
            ),
          ),
          onSubmitted: (_) {
            _apply(controller.text);
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ),
          TextButton(
            onPressed: () {
              _apply(controller.text);
              Navigator.of(ctx).pop();
            },
            child: Text(
              'OK',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _apply(String input) {
    final value = double.tryParse(input);
    if (value != null && value >= 1.0 && value <= 20154.0) {
      widget.provider.setFrequency(widget.ch.id, value);
    }
  }
}

/// Waveform selector dropdown
class _WaveformDropdown extends StatelessWidget {
  final Waveform waveform;
  final ValueChanged<Waveform> onChanged;

  const _WaveformDropdown({
    required this.waveform,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Waveform>(
      onSelected: onChanged,
      initialValue: waveform,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 140),
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      offset: const Offset(0, 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _waveformIcon(waveform.index, 12, Colors.white54),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 12, color: Colors.white24),
          ],
        ),
      ),
      itemBuilder: (_) => List.generate(Waveform.values.length, (i) {
        final wf = Waveform.values[i];
        final isActive = wf == waveform;
        return PopupMenuItem(
          value: wf,
          height: 36,
          child: Row(
            children: [
              _waveformIcon(
                i,
                18,
                isActive ? const Color(0xFF6C63FF) : Colors.white54,
              ),
              const SizedBox(width: 10),
              Text(
                _waveformLabels[i],
                style: TextStyle(
                  color: isActive ? const Color(0xFF6C63FF) : Colors.white70,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Toggle chip (M / S / Ø)
class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: active
              ? activeColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: active ? activeColor.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: active ? activeColor : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Octave shift button (×½ / ×2)
class _OctaveButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OctaveButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.35),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Delete / close button
class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.close,
          size: 14,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Waveform icons
// ════════════════════════════════════════════════════════════════

Widget _waveformIcon(int index, double size, Color color) {
  switch (index) {
    case 0:
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _SineWavePainter(color: color)),
      );
    case 1:
      return Icon(Icons.square_outlined, size: size, color: color);
    case 2:
      return Icon(Icons.change_history, size: size, color: color);
    case 3:
      return Icon(Icons.show_chart, size: size, color: color);
    default:
      return Icon(Icons.waves, size: size, color: color);
  }
}

class _SineWavePainter extends CustomPainter {
  final Color color;
  _SineWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final midY = size.height / 2;
    final amp = size.height * 0.35;
    for (int i = 0; i <= 40; i++) {
      final x = (i / 40) * size.width;
      final y = midY - amp * math.sin(2 * math.pi * (i / 40));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SineWavePainter old) => old.color != color;
}
