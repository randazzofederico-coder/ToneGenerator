import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/channel_model.dart';
import 'package:native_audio_engine/live_mixer.dart';

/// Predefined channel colors
const List<Color> channelColors = [
  Color(0xFF6C63FF), // purple
  Color(0xFF00D2FF), // cyan
  Color(0xFF00E676), // green
  Color(0xFFFF9800), // orange
  Color(0xFFE94560), // red/pink
  Color(0xFFFFD700), // yellow
  Color(0xFFFF5722), // deep orange
  Color(0xFF9C27B0), // purple dark
  Color(0xFF00BCD4), // teal
  Color(0xFF8BC34A), // lime
];

Color channelColor(int index) => channelColors[index % channelColors.length];

class ToneGeneratorProvider extends ChangeNotifier {
  late LiveMixer _mixer;
  final List<ToneChannel> _channels = [];
  bool _isPlaying = false;
  bool _isReady = false;
  double _masterVolume = 0.8;
  String? _selectedChannelId;
  
  // Throttle UI rebuilds during continuous slider drags
  DateTime _lastNotifyTime = DateTime.now();
  static const _notifyThrottle = Duration(milliseconds: 16); // ~60fps max

  static const _uuid = Uuid();

  List<ToneChannel> get channels => List.unmodifiable(_channels);
  bool get isPlaying => _isPlaying;
  bool get isReady => _isReady;
  double get masterVolume => _masterVolume;
  String? get selectedChannelId => _selectedChannelId;

  /// Index of a channel by its id (used for color mapping)
  int channelIndex(String id) {
    for (int i = 0; i < _channels.length; i++) {
      if (_channels[i].id == id) return i;
    }
    return 0;
  }

  Future<void> init() async {
    _mixer = LiveMixer();
    await _mixer.init();
    _isReady = true;
    _mixer.setMasterVolume(_masterVolume);
    notifyListeners();
  }

  // --- Selection ---

  void selectChannel(String? id) {
    _selectedChannelId = id;
    notifyListeners();
  }

  // --- Channel CRUD ---

  String addChannel({double freq = 440.0, Waveform waveform = Waveform.sine}) {
    final id = _uuid.v4();
    final channel = ToneChannel(
      id: id,
      frequency: freq,
      waveform: waveform,
      volume: 0.3,
      noteName: ToneChannel.frequencyToNoteName(freq),
    );
    _channels.add(channel);
    
    if (_isReady) {
      _mixer.addOscillator(id, freq, waveform.index);
      _mixer.setOscillatorVolume(id, 0.3);
    }

    // Auto-select the new channel
    _selectedChannelId = id;
    
    notifyListeners();
    return id;
  }

  void removeChannel(String id) {
    _channels.removeWhere((ch) => ch.id == id);
    if (_isReady) {
      _mixer.removeOscillator(id);
    }
    // If we removed the selected channel, select another
    if (_selectedChannelId == id) {
      _selectedChannelId = _channels.isNotEmpty ? _channels.last.id : null;
    }
    notifyListeners();
  }

  void setFrequency(String id, double freq) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.frequency = freq;
    ch.noteName = ToneChannel.frequencyToNoteName(freq);
    if (_isReady) _mixer.setOscillatorFreq(id, freq);
    _throttledNotify();
  }

  void setNote(String id, String noteName, int octave) {
    final freq = ToneChannel.noteNameToFrequency(noteName, octave);
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.frequency = freq;
    ch.noteName = '$noteName$octave';
    if (_isReady) _mixer.setOscillatorFreq(id, freq);
    notifyListeners();
  }

  void setWaveform(String id, Waveform waveform) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.waveform = waveform;
    if (_isReady) _mixer.setOscillatorWaveform(id, waveform.index);
    notifyListeners();
  }

  void setVolume(String id, double volume) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.volume = volume;
    if (_isReady) _mixer.setOscillatorVolume(id, volume);
    _throttledNotify();
  }

  void setPan(String id, double pan) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.pan = pan;
    if (_isReady) _mixer.setOscillatorPan(id, pan);
    _throttledNotify();
  }

  void toggleMute(String id) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.muted = !ch.muted;
    if (_isReady) _mixer.setOscillatorMute(id, ch.muted);
    notifyListeners();
  }

  void toggleSolo(String id) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.solo = !ch.solo;
    if (_isReady) _mixer.setOscillatorSolo(id, ch.solo);
    notifyListeners();
  }

  void togglePhaseInvert(String id) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.phaseInvert = !ch.phaseInvert;
    if (_isReady) _mixer.setOscillatorPhaseInvert(id, ch.phaseInvert);
    notifyListeners();
  }

  // --- Master ---

  void setMasterVolume(double vol) {
    _masterVolume = vol;
    if (_isReady) _mixer.setMasterVolume(vol);
    _throttledNotify();
  }

  // --- Playback ---

  void togglePlayback() {
    if (_isPlaying) {
      stop();
    } else {
      play();
    }
  }

  void play() {
    if (!_isReady) return;
    _mixer.startPlayback();
    _isPlaying = true;
    notifyListeners();
  }

  void stop() {
    if (!_isReady) return;
    _mixer.stopPlayback();
    _isPlaying = false;
    notifyListeners();
  }

  // --- Serialization (for sharing) ---

  String sessionToJson() {
    final data = {
      'channels': _channels.map((ch) => ch.toJson()).toList(),
      'masterVol': _masterVolume,
    };
    return jsonEncode(data);
  }

  String channelToJson(String id) {
    final ch = _findChannel(id);
    if (ch == null) return '{}';
    return jsonEncode(ch.toJson());
  }

  void loadSessionFromJson(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // Clear existing
      for (final ch in List.of(_channels)) {
        removeChannel(ch.id);
      }
      
      _masterVolume = (data['masterVol'] as num?)?.toDouble() ?? 0.8;
      if (_isReady) _mixer.setMasterVolume(_masterVolume);
      
      final channelsJson = data['channels'] as List<dynamic>? ?? [];
      for (final chJson in channelsJson) {
        final id = _uuid.v4();
        final ch = ToneChannel.fromJson(id, chJson as Map<String, dynamic>);
        _channels.add(ch);
        if (_isReady) {
          _mixer.addOscillator(id, ch.frequency, ch.waveformIndex);
          _mixer.setOscillatorVolume(id, ch.volume);
          _mixer.setOscillatorPan(id, ch.pan);
          _mixer.setOscillatorMute(id, ch.muted);
          _mixer.setOscillatorSolo(id, ch.solo);
          _mixer.setOscillatorPhaseInvert(id, ch.phaseInvert);
        }
      }
      
      if (_channels.isNotEmpty) {
        _selectedChannelId = _channels.first.id;
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading session: $e');
    }
  }

  void loadChannelFromJson(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final id = _uuid.v4();
      final ch = ToneChannel.fromJson(id, data);
      _channels.add(ch);
      if (_isReady) {
        _mixer.addOscillator(id, ch.frequency, ch.waveformIndex);
        _mixer.setOscillatorVolume(id, ch.volume);
        _mixer.setOscillatorPan(id, ch.pan);
        _mixer.setOscillatorMute(id, ch.muted);
        _mixer.setOscillatorSolo(id, ch.solo);
        _mixer.setOscillatorPhaseInvert(id, ch.phaseInvert);
      }
      _selectedChannelId = id;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading channel: $e');
    }
  }

  // --- Internal ---

  ToneChannel? _findChannel(String id) {
    for (final ch in _channels) {
      if (ch.id == id) return ch;
    }
    return null;
  }

  /// Throttled notify — sends engine updates immediately but limits UI rebuilds
  void _throttledNotify() {
    final now = DateTime.now();
    if (now.difference(_lastNotifyTime) >= _notifyThrottle) {
      _lastNotifyTime = now;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isReady) {
      _mixer.stopPlayback();
      _mixer.dispose();
    }
    super.dispose();
  }
}
