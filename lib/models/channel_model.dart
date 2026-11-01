import 'dart:math' as math;

enum Waveform { sine, square, triangle, sawtooth }

const List<String> _noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

class ToneChannel {
  final String id;
  double frequency; // 1 - 20154 Hz
  Waveform waveform;
  double volume; // 0.0 - 1.0
  double pan; // -1.0 (L) to 1.0 (R)
  bool muted;
  bool solo;
  bool phaseInvert;
  String? noteName; // e.g. "A4", null if free frequency

  ToneChannel({
    required this.id,
    this.frequency = 440.0,
    this.waveform = Waveform.sine,
    this.volume = 0.5,
    this.pan = 0.0,
    this.muted = false,
    this.solo = false,
    this.phaseInvert = false,
    this.noteName,
  });

  /// Returns the waveform as an int for the C++ engine (0=sin, 1=sq, 2=tri, 3=saw)
  int get waveformIndex => waveform.index;

  /// Frequency → note name with octave (equal temperament, A4=440Hz)
  static String frequencyToNoteName(double freq) {
    if (freq <= 0) return '--';
    double midiNote = 12 * (math.log(freq / 440.0) / math.ln2) + 69;
    int midiInt = midiNote.round();
    int noteIndex = midiInt % 12;
    int octave = (midiInt ~/ 12) - 1;
    return '${_noteNames[noteIndex]}$octave';
  }

  /// Display note name with ~ prefix if not exactly on a tempered pitch
  static String displayNoteName(double freq) {
    if (freq <= 0) return '--';
    double midiNote = 12 * (math.log(freq / 440.0) / math.ln2) + 69;
    int midiInt = midiNote.round();
    double centsOff = (midiNote - midiInt) * 100; // cents deviation
    int noteIndex = midiInt % 12;
    int octave = (midiInt ~/ 12) - 1;
    String name = '${_noteNames[noteIndex]}$octave';
    // If more than 2 cents off, show ~ prefix
    if (centsOff.abs() > 2) {
      return '~$name';
    }
    return name;
  }

  /// Note name (e.g. 'C', 'C#') + octave → frequency in Hz
  static double noteNameToFrequency(String name, int octave) {
    const semitones = {
      'C': 0, 'C#': 1, 'Db': 1,
      'D': 2, 'D#': 3, 'Eb': 3,
      'E': 4,
      'F': 5, 'F#': 6, 'Gb': 6,
      'G': 7, 'G#': 8, 'Ab': 8,
      'A': 9, 'A#': 10, 'Bb': 10,
      'B': 11,
    };
    int? sem = semitones[name];
    if (sem == null) return 440.0;
    // MIDI note: C0 = 12, A4 = 69
    int midiNote = (octave + 1) * 12 + sem;
    return 440.0 * math.pow(2.0, (midiNote - 69) / 12.0);
  }

  /// Generate all notes from C0 to B8 as (noteName, octave, frequency)
  static List<({String name, int octave, double freq})> allNotes() {
    final result = <({String name, int octave, double freq})>[];
    for (int oct = 0; oct <= 8; oct++) {
      for (final name in _noteNames) {
        double freq = noteNameToFrequency(name, oct);
        if (freq >= 1.0 && freq <= 20154.0) {
          result.add((name: name, octave: oct, freq: freq));
        }
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'f': frequency,
    'w': waveform.index,
    'v': volume,
    'p': pan,
    'm': muted,
    's': solo,
    'i': phaseInvert,
    'n': noteName,
  };

  factory ToneChannel.fromJson(String id, Map<String, dynamic> json) {
    return ToneChannel(
      id: id,
      frequency: (json['f'] as num?)?.toDouble() ?? 440.0,
      waveform: Waveform.values[(json['w'] as int?) ?? 0],
      volume: (json['v'] as num?)?.toDouble() ?? 0.5,
      pan: (json['p'] as num?)?.toDouble() ?? 0.0,
      muted: json['m'] as bool? ?? false,
      solo: json['s'] as bool? ?? false,
      phaseInvert: json['i'] as bool? ?? false,
      noteName: json['n'] as String?,
    );
  }

  ToneChannel copyWith({
    String? id,
    double? frequency,
    Waveform? waveform,
    double? volume,
    double? pan,
    bool? muted,
    bool? solo,
    bool? phaseInvert,
    String? noteName,
  }) {
    return ToneChannel(
      id: id ?? this.id,
      frequency: frequency ?? this.frequency,
      waveform: waveform ?? this.waveform,
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
      muted: muted ?? this.muted,
      solo: solo ?? this.solo,
      phaseInvert: phaseInvert ?? this.phaseInvert,
      noteName: noteName ?? this.noteName,
    );
  }
}
