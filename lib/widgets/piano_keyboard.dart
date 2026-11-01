import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/channel_model.dart';
import '../providers/tone_generator_provider.dart';

// Key dimensions (shared between GlobalPianoKeyboard and _OctaveGroup)
const double _whiteKeyWidth = 36.0;
const double _whiteKeyHeight = 90.0;
const double _blackKeyWidth = 22.0;
const double _blackKeyHeight = 56.0;

/// Global piano keyboard shown at the bottom of the screen.
/// Shows colored dots for each channel on the keys they're using.
/// Has a channel selector bar at the top.
class GlobalPianoKeyboard extends StatefulWidget {
  const GlobalPianoKeyboard({super.key});

  @override
  State<GlobalPianoKeyboard> createState() => _GlobalPianoKeyboardState();
}

class _GlobalPianoKeyboardState extends State<GlobalPianoKeyboard> {
  final ScrollController _scrollController = ScrollController();

  static const _whiteNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const List<(int, String)> _blackKeys = [
    (0, 'C#'),
    (1, 'D#'),
    (3, 'F#'),
    (4, 'G#'),
    (5, 'A#'),
  ];



  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ToneGeneratorProvider>(
      builder: (context, provider, _) {
        if (provider.channels.isEmpty) return const SizedBox.shrink();

        final selectedId = provider.selectedChannelId;

        // Build a map of note -> list of (channelIndex, channelId) for dots
        final Map<String, List<int>> noteToChannelIndices = {};
        for (int i = 0; i < provider.channels.length; i++) {
          final ch = provider.channels[i];
          final note = ch.noteName;
          if (note != null && note.isNotEmpty) {
            noteToChannelIndices.putIfAbsent(note, () => []);
            noteToChannelIndices[note]!.add(i);
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D1A),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- CHANNEL SELECTOR BAR ---
                _ChannelSelectorBar(
                  channels: provider.channels,
                  selectedId: selectedId,
                  onSelect: (id) => provider.selectChannel(id),
                ),

                // --- PIANO KEYS ---
                SizedBox(
                  height: _whiteKeyHeight + 12,
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(9, (octave) {
                          return _OctaveGroup(
                            octave: octave,
                            selectedChannelId: selectedId,
                            noteToChannelIndices: noteToChannelIndices,
                            onNoteTapped: (name, oct) {
                              if (selectedId != null) {
                                provider.setNote(selectedId, name, oct);
                              }
                            },
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChannelSelectorBar extends StatelessWidget {
  final List<ToneChannel> channels;
  final String? selectedId;
  final void Function(String id) onSelect;

  const _ChannelSelectorBar({
    required this.channels,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.piano, size: 16, color: Colors.white.withOpacity(0.3)),
          const SizedBox(width: 8),
          Text(
            'Canal:',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.4),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(channels.length, (i) {
                  final ch = channels[i];
                  final color = channelColor(i);
                  final isSelected = ch.id == selectedId;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => onSelect(ch.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected
                              ? color.withOpacity(0.3)
                              : Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: isSelected
                                ? color.withOpacity(0.7)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withOpacity(0.5),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? color
                                    : Colors.white.withOpacity(0.5),
                              ),
                            ),
                            if (ch.noteName != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                ch.noteName!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.35),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OctaveGroup extends StatelessWidget {
  final int octave;
  final String? selectedChannelId;
  final Map<String, List<int>> noteToChannelIndices;
  final void Function(String noteName, int octave) onNoteTapped;

  const _OctaveGroup({
    required this.octave,
    required this.selectedChannelId,
    required this.noteToChannelIndices,
    required this.onNoteTapped,
  });

  static const _whiteNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const List<(int, String)> _blackKeys = [
    (0, 'C#'),
    (1, 'D#'),
    (3, 'F#'),
    (4, 'G#'),
    (5, 'A#'),
  ];

  @override
  Widget build(BuildContext context) {
    const whiteKeyWidth = _whiteKeyWidth;
    const whiteKeyHeight = _whiteKeyHeight;
    const blackKeyWidth = _blackKeyWidth;
    const blackKeyHeight = _blackKeyHeight;

    final octaveWidth = _whiteNotes.length * whiteKeyWidth;

    return SizedBox(
      width: octaveWidth,
      height: whiteKeyHeight + 12,
      child: Stack(
        children: [
          // White keys
          Row(
            children: _whiteNotes.map((note) {
              final noteStr = '$note$octave';
              final channelIndices = noteToChannelIndices[noteStr];
              final hasChannel = channelIndices != null && channelIndices.isNotEmpty;

              return GestureDetector(
                onTap: () => onNoteTapped(note, octave),
                child: Container(
                  width: whiteKeyWidth - 1, // -1 for right margin gap
                  height: whiteKeyHeight,
                  margin: const EdgeInsets.only(top: 8, right: 1),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(6),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: hasChannel
                          ? [
                              channelColor(channelIndices!.first).withOpacity(0.3),
                              const Color(0xFFD0D0D0),
                            ]
                          : [const Color(0xFFE8E8E8), const Color(0xFFD0D0D0)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Channel color dots
                      if (hasChannel)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            alignment: WrapAlignment.center,
                            children: channelIndices!.map((idx) {
                              return Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: channelColor(idx),
                                  boxShadow: [
                                    BoxShadow(
                                      color: channelColor(idx).withOpacity(0.6),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      // Note label
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '$note$octave',
                          style: const TextStyle(
                            fontSize: 8,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Black keys
          ..._blackKeys.map((entry) {
            final (whiteIndex, noteName) = entry;
            final noteStr = '$noteName$octave';
            final channelIndices = noteToChannelIndices[noteStr];
            final hasChannel = channelIndices != null && channelIndices.isNotEmpty;
            final leftOffset =
                (whiteIndex + 1) * whiteKeyWidth - blackKeyWidth / 2;

            return Positioned(
              left: leftOffset,
              top: 8,
              child: GestureDetector(
                onTap: () => onNoteTapped(noteName, octave),
                child: Container(
                  width: blackKeyWidth,
                  height: blackKeyHeight,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(4),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: hasChannel
                          ? [
                              channelColor(channelIndices!.first).withOpacity(0.6),
                              const Color(0xFF1A1A1A),
                            ]
                          : [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasChannel)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Wrap(
                            spacing: 2,
                            alignment: WrapAlignment.center,
                            children: channelIndices!.map((idx) {
                              return Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: channelColor(idx),
                                  boxShadow: [
                                    BoxShadow(
                                      color: channelColor(idx).withOpacity(0.7),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          noteName,
                          style: TextStyle(
                            fontSize: 7,
                            color: Colors.white.withOpacity(0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Octave label
          Positioned(
            left: 2,
            bottom: 0,
            child: Text(
              'Oct $octave',
              style: TextStyle(
                fontSize: 7,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
