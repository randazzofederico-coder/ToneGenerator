import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/channel_model.dart';
import '../models/tone_session.dart';
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

  // --- Active session / dirty tracking ---
  String? _activeSessionId;
  String? _activeSessionName;

  /// State key of the active session as last saved/opened.
  String? _savedSnapshot;

  /// Incremented whenever all channels are replaced (open / new / restore),
  /// so stale undo actions can't touch a different session.
  int _generation = 0;

  // --- Working state persistence ---
  static const _workingStateKey = 'tone_working_state';
  Timer? _saveTimer;
  final Completer<void> _restored = Completer<void>();

  List<ToneChannel> get channels => List.unmodifiable(_channels);
  bool get isPlaying => _isPlaying;
  bool get isReady => _isReady;
  double get masterVolume => _masterVolume;
  String? get selectedChannelId => _selectedChannelId;

  /// Completes once the engine is ready and the last working state restored.
  Future<void> get ready => _restored.future;

  /// ID of the library session currently open (null = unsaved "Sin título").
  String? get activeSessionId => _activeSessionId;
  String? get activeSessionName => _activeSessionName;

  /// Name shown in the UI.
  String get displayName => _activeSessionName ?? 'Sin título';

  /// True when the current state differs from the open session as saved.
  /// For an unsaved session, true as soon as there is any channel.
  bool get isDirty {
    if (_activeSessionId == null) return _channels.isNotEmpty;
    return _stateKey() != _savedSnapshot;
  }

  /// Index of a channel by its id (used for color mapping)
  int channelIndex(String id) {
    for (int i = 0; i < _channels.length; i++) {
      if (_channels[i].id == id) return i;
    }
    return 0;
  }

  Future<void> init() async {
    try {
      _mixer = LiveMixer();
      await _mixer.init();
      _isReady = true;
      _mixer.setMasterVolume(_masterVolume);
      await _restoreWorkingState();
    } finally {
      if (!_restored.isCompleted) _restored.complete();
      notifyListeners();
    }
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

    _changed();
    return id;
  }

  /// Removes a channel. Returns what is needed to undo it (or null).
  ({ToneChannel channel, int index, int generation})? removeChannel(String id) {
    final index = _channels.indexWhere((ch) => ch.id == id);
    if (index < 0) return null;
    final removed = _channels.removeAt(index);
    if (_isReady) {
      _mixer.removeOscillator(id);
    }
    // If we removed the selected channel, select another
    if (_selectedChannelId == id) {
      _selectedChannelId = _channels.isNotEmpty ? _channels.last.id : null;
    }
    _changed();
    return (channel: removed, index: index, generation: _generation);
  }

  /// Undo of [removeChannel]. Ignored if another session was loaded since
  /// ([generation] changed) or the channel is already back.
  bool restoreChannel(ToneChannel ch, int index, int generation) {
    if (generation != _generation || _findChannel(ch.id) != null) return false;
    _channels.insert(index.clamp(0, _channels.length), ch);
    if (_isReady) _addToMixer(ch);
    _selectedChannelId = ch.id;
    _changed();
    return true;
  }

  void setFrequency(String id, double freq) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.frequency = freq;
    ch.noteName = ToneChannel.frequencyToNoteName(freq);
    if (_isReady) _mixer.setOscillatorFreq(id, freq);
    _changed(throttled: true);
  }

  void setNote(String id, String noteName, int octave) {
    final freq = ToneChannel.noteNameToFrequency(noteName, octave);
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.frequency = freq;
    ch.noteName = '$noteName$octave';
    if (_isReady) _mixer.setOscillatorFreq(id, freq);
    _changed();
  }

  void setWaveform(String id, Waveform waveform) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.waveform = waveform;
    if (_isReady) _mixer.setOscillatorWaveform(id, waveform.index);
    _changed();
  }

  void setVolume(String id, double volume) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.volume = volume;
    if (_isReady) _mixer.setOscillatorVolume(id, volume);
    _changed(throttled: true);
  }

  void setPan(String id, double pan) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.pan = pan;
    if (_isReady) _mixer.setOscillatorPan(id, pan);
    _changed(throttled: true);
  }

  void toggleMute(String id) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.muted = !ch.muted;
    if (_isReady) _mixer.setOscillatorMute(id, ch.muted);
    _changed();
  }

  void toggleSolo(String id) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.solo = !ch.solo;
    if (_isReady) _mixer.setOscillatorSolo(id, ch.solo);
    _changed();
  }

  void togglePhaseInvert(String id) {
    final ch = _findChannel(id);
    if (ch == null) return;
    ch.phaseInvert = !ch.phaseInvert;
    if (_isReady) _mixer.setOscillatorPhaseInvert(id, ch.phaseInvert);
    _changed();
  }

  // --- Master ---

  void setMasterVolume(double vol) {
    _masterVolume = vol;
    if (_isReady) _mixer.setMasterVolume(vol);
    _changed(throttled: true);
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

  // --- Sessions ---

  /// Captures the current state as a session. Without [id] it reuses the
  /// active session's ID (or a new one if there is none).
  ToneSession captureSession({String? id, String? name, DateTime? createdAt}) {
    return ToneSession.capture(
      id: id ?? _activeSessionId,
      name: name ?? displayName,
      channels: _channels,
      masterVolume: _masterVolume,
      createdAt: createdAt,
    );
  }

  /// Loads [session] replacing the current channels. Playback is always
  /// stopped first: a session (own or received) never starts sounding alone.
  void loadSession(ToneSession session) {
    if (_isPlaying) stop();
    _applyState(session.buildChannels(), session.masterVolume);
    _activeSessionId = session.id;
    _activeSessionName = session.name;
    _savedSnapshot = _stateKey();
    _changed();
  }

  /// Starts a new, empty, unsaved session.
  void newSession() {
    if (_isPlaying) stop();
    _applyState(const [], 0.8);
    _activeSessionId = null;
    _activeSessionName = null;
    _savedSnapshot = null;
    _changed();
  }

  /// Marks the current state as saved under [session] (after saving it).
  void markSaved(ToneSession session) {
    _activeSessionId = session.id;
    _activeSessionName = session.name;
    _savedSnapshot = _stateKey();
    _changed();
  }

  /// Sets the "saved" reference to [session] without touching the channels
  /// (used to undo an overwrite: the working state becomes dirty again).
  void setSavedReference(ToneSession session) {
    _activeSessionId = session.id;
    _activeSessionName = session.name;
    _savedSnapshot = _stateKeyFor(session.channels, session.masterVolume);
    _changed();
  }

  /// Updates the active session name (after a rename in the library).
  void renameActive(String name) {
    _activeSessionName = name;
    _changed();
  }

  /// The active session was deleted from the library: keep working on the
  /// same channels as an unsaved session (name and snapshot are kept so an
  /// undo can re-attach it).
  void detachActive() {
    _activeSessionId = null;
    _changed();
  }

  /// Re-attaches a session restored by undo, if nothing else was opened.
  void reattach(ToneSession session) {
    if (_activeSessionId != null || _activeSessionName != session.name) return;
    _activeSessionId = session.id;
    _changed();
  }

  // --- Internal ---

  ToneChannel? _findChannel(String id) {
    for (final ch in _channels) {
      if (ch.id == id) return ch;
    }
    return null;
  }

  /// Replaces all channels in the engine and in memory (no notification).
  void _applyState(List<ToneChannel> channels, double masterVolume) {
    if (_isReady) {
      for (final ch in _channels) {
        _mixer.removeOscillator(ch.id);
      }
    }
    _channels
      ..clear()
      ..addAll(channels);

    _masterVolume = masterVolume;
    if (_isReady) {
      _mixer.setMasterVolume(_masterVolume);
      for (final ch in _channels) {
        _addToMixer(ch);
      }
    }
    _selectedChannelId = _channels.isNotEmpty ? _channels.first.id : null;
    _generation++;
  }

  void _addToMixer(ToneChannel ch) {
    _mixer.addOscillator(ch.id, ch.frequency, ch.waveformIndex);
    _mixer.setOscillatorVolume(ch.id, ch.volume);
    _mixer.setOscillatorPan(ch.id, ch.pan);
    _mixer.setOscillatorMute(ch.id, ch.muted);
    _mixer.setOscillatorSolo(ch.id, ch.solo);
    _mixer.setOscillatorPhaseInvert(ch.id, ch.phaseInvert);
  }

  String _stateKeyFor(List<Map<String, dynamic>> channels, double master) =>
      jsonEncode({'c': channels, 'm': master});

  String _stateKey() =>
      _stateKeyFor(_channels.map((c) => c.toJson()).toList(), _masterVolume);

  /// Notifies listeners (optionally throttled) and schedules a save of the
  /// working state.
  void _changed({bool throttled = false}) {
    _scheduleSave();
    if (!throttled) {
      notifyListeners();
      return;
    }
    // Throttled notify — engine updates are immediate, UI rebuilds limited
    final now = DateTime.now();
    if (now.difference(_lastNotifyTime) >= _notifyThrottle) {
      _lastNotifyTime = now;
      notifyListeners();
    }
  }

  void _scheduleSave() {
    if (!_restored.isCompleted) return; // don't overwrite before restoring
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveWorkingState);
  }

  Future<void> _saveWorkingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _workingStateKey,
        jsonEncode({
          'channels': _channels.map((c) => c.toJson()).toList(),
          'masterVol': _masterVolume,
          'activeId': _activeSessionId,
          'activeName': _activeSessionName,
          'snapshot': _savedSnapshot,
        }),
      );
    } catch (e) {
      debugPrint('Error saving working state: $e');
    }
  }

  Future<void> _restoreWorkingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_workingStateKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      // Reuse the defensive session parser for channels and volume.
      final session = ToneSession.fromJson({
        'name': data['activeName'],
        'channels': data['channels'],
        'masterVol': data['masterVol'],
      });
      _applyState(session.buildChannels(), session.masterVolume);
      _activeSessionId = data['activeId'] as String?;
      _activeSessionName = data['activeName'] as String?;
      _savedSnapshot = data['snapshot'] as String?;
    } catch (e) {
      debugPrint('Error restoring working state: $e');
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_isReady) {
      _mixer.stopPlayback();
      _mixer.dispose();
    }
    super.dispose();
  }
}
