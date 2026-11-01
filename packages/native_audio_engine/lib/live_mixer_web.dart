import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:async';

// ---------------------------------------------------------------------------
// Web Audio API implementation using NATIVE nodes (no WASM, no AudioWorklet).
//
// Each oscillator channel becomes:
//   OscillatorNode → GainNode (vol + mute + phase) → StereoPannerNode → masterGain → destination
//
// All parameter changes use setTargetAtTime() for sample-accurate smoothing.
// ---------------------------------------------------------------------------

@JS('AudioContext')
external JSFunction? get _audioContextConstructor;
@JS('webkitAudioContext')
external JSFunction? get _webkitAudioContextConstructor;

JSObject _createAudioContext() {
  if (_audioContextConstructor != null) {
    return _audioContextConstructor!.callAsConstructor();
  }
  if (_webkitAudioContextConstructor != null) {
    return _webkitAudioContextConstructor!.callAsConstructor();
  }
  throw UnsupportedError('AudioContext not supported.');
}

class _WebChannel {
  final JSObject oscillator;
  final JSObject gainNode;
  final JSObject pannerNode;
  double volume;
  bool muted;
  bool solo;
  bool phaseInvert;

  _WebChannel({
    required this.oscillator,
    required this.gainNode,
    required this.pannerNode,
    this.volume = 0.3,
    this.muted = false,
    this.solo = false,
    this.phaseInvert = false,
  });
}

class LiveMixer {
  bool isReady = false;
  bool _isDisposed = false;
  bool _isPlaying = false;

  JSObject? _audioContext;
  JSObject? _masterGainNode;

  final Map<String, _WebChannel> _channels = {};
  double _masterVolume = 1.0;
  bool _masterMuted = false;
  bool _anyOscSolo = false;

  // Smoothing time constants (seconds) — matched to szynalski-style feel
  static const double _freqSmooth = 0.005;   // 5ms — fast pitch glide
  static const double _gainSmooth = 0.010;   // 10ms — smooth volume
  static const double _panSmooth = 0.010;    // 10ms — smooth pan
  static const double _masterSmooth = 0.020; // 20ms — master fade

  LiveMixer();

  Future<void> init() async {
    _audioContext = _createAudioContext();

    // Create master gain node → destination
    _masterGainNode = _audioContext!.callMethod<JSObject>('createGain'.toJS);
    final dest = _audioContext!.getProperty('destination'.toJS) as JSObject;
    _masterGainNode!.callMethod('connect'.toJS, dest);

    // Start silent (will open on startPlayback)
    final masterGainParam = _masterGainNode!.getProperty('gain'.toJS) as JSObject;
    masterGainParam.setProperty('value'.toJS, 0.0.toJS);

    isReady = true;
  }

  /// Current audio context time (seconds)
  double get _now {
    try {
      return (_audioContext?.getProperty('currentTime'.toJS) as JSNumber?)
              ?.toDartDouble ??
          0.0;
    } catch (_) {
      return 0.0;
    }
  }

  // --- Oscillator API ---

  void addOscillator(String id, double freq, int waveform) {
    if (_isDisposed || !isReady || _audioContext == null) return;

    // Remove existing if re-adding
    if (_channels.containsKey(id)) {
      removeOscillator(id);
    }

    final ctx = _audioContext!;

    // Create: OscillatorNode → GainNode → StereoPannerNode → masterGain
    final osc = ctx.callMethod<JSObject>('createOscillator'.toJS);
    final gain = ctx.callMethod<JSObject>('createGain'.toJS);
    final panner = ctx.callMethod<JSObject>('createStereoPanner'.toJS);

    // Set waveform type
    osc.setProperty('type'.toJS, _waveformName(waveform).toJS);

    // Set initial frequency
    final freqParam = osc.getProperty('frequency'.toJS) as JSObject;
    freqParam.setProperty('value'.toJS, freq.toJS);

    // Set initial gain (vol² curve, default 0.3 → 0.09)
    final gainParam = gain.getProperty('gain'.toJS) as JSObject;
    gainParam.setProperty('value'.toJS, (0.3 * 0.3).toJS);

    // Set initial pan (center)
    final panParam = panner.getProperty('pan'.toJS) as JSObject;
    panParam.setProperty('value'.toJS, 0.0.toJS);

    // Wire: osc → gain → panner → masterGain
    osc.callMethod('connect'.toJS, gain);
    gain.callMethod('connect'.toJS, panner);
    panner.callMethod('connect'.toJS, _masterGainNode!);

    // Start oscillator immediately (runs forever until stopped)
    osc.callMethod('start'.toJS);

    _channels[id] = _WebChannel(
      oscillator: osc,
      gainNode: gain,
      pannerNode: panner,
      volume: 0.3,
    );
  }

  void removeOscillator(String id) {
    final ch = _channels.remove(id);
    if (ch == null) return;
    try {
      ch.oscillator.callMethod('stop'.toJS);
      ch.oscillator.callMethod('disconnect'.toJS);
      ch.gainNode.callMethod('disconnect'.toJS);
      ch.pannerNode.callMethod('disconnect'.toJS);
    } catch (_) {}
    _updateSoloState();
  }

  void setOscillatorFreq(String id, double freq) {
    final ch = _channels[id];
    if (ch == null) return;
    final freqParam = ch.oscillator.getProperty('frequency'.toJS) as JSObject;
    freqParam.callMethod(
      'setTargetAtTime'.toJS,
      freq.toJS,
      _now.toJS,
      _freqSmooth.toJS,
    );
  }

  void setOscillatorWaveform(String id, int waveform) {
    final ch = _channels[id];
    if (ch == null) return;
    ch.oscillator.setProperty('type'.toJS, _waveformName(waveform).toJS);
  }

  void setOscillatorVolume(String id, double volume) {
    final ch = _channels[id];
    if (ch == null) return;
    ch.volume = volume;
    _updateChannelGain(ch);
  }

  void setOscillatorPan(String id, double pan) {
    final ch = _channels[id];
    if (ch == null) return;
    final panParam = ch.pannerNode.getProperty('pan'.toJS) as JSObject;
    panParam.callMethod(
      'setTargetAtTime'.toJS,
      pan.toJS,
      _now.toJS,
      _panSmooth.toJS,
    );
  }

  void setOscillatorMute(String id, bool muted) {
    final ch = _channels[id];
    if (ch == null) return;
    ch.muted = muted;
    _updateChannelGain(ch);
  }

  void setOscillatorSolo(String id, bool solo) {
    final ch = _channels[id];
    if (ch == null) return;
    ch.solo = solo;
    _updateSoloState();
  }

  void setOscillatorPhaseInvert(String id, bool invert) {
    final ch = _channels[id];
    if (ch == null) return;
    ch.phaseInvert = invert;
    _updateChannelGain(ch);
  }

  // --- Master ---

  void setMasterVolume(double volume) {
    _masterVolume = volume;
    _updateMasterGain();
  }

  void setMasterMute(bool muted) {
    _masterMuted = muted;
    _updateMasterGain();
  }

  // --- Playback ---

  void startPlayback() {
    if (_isDisposed || !isReady) return;
    _isPlaying = true;

    // Resume AudioContext if suspended (browser autoplay policy)
    try {
      final state = (_audioContext!.getProperty('state'.toJS) as JSString).toDart;
      if (state != 'running') {
        _audioContext!.callMethod('resume'.toJS);
      }
    } catch (_) {}

    _updateMasterGain();
  }

  void stopPlayback() {
    if (_isDisposed || !isReady) return;
    _isPlaying = false;
    _updateMasterGain();
  }

  int getSampleRate() {
    if (_audioContext != null) {
      try {
        return (_audioContext!.getProperty('sampleRate'.toJS) as JSNumber?)
                ?.toDartDouble
                .toInt() ??
            44100;
      } catch (_) {}
    }
    return 44100;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    for (final ch in _channels.values) {
      try {
        ch.oscillator.callMethod('stop'.toJS);
        ch.oscillator.callMethod('disconnect'.toJS);
        ch.gainNode.callMethod('disconnect'.toJS);
        ch.pannerNode.callMethod('disconnect'.toJS);
      } catch (_) {}
    }
    _channels.clear();

    try {
      _audioContext?.callMethod('close'.toJS);
    } catch (_) {}
  }

  // --- Internal: gain calculations ---

  /// Update a single channel's gain based on volume, mute, solo, phase invert
  void _updateChannelGain(_WebChannel ch) {
    double effectiveGain;

    // Mute / Solo logic
    bool shouldPlay = true;
    if (_anyOscSolo) {
      shouldPlay = ch.solo;
    } else {
      shouldPlay = !ch.muted;
    }

    if (shouldPlay) {
      // vol² curve for intuitive slider feel
      effectiveGain = ch.volume * ch.volume;
      // Phase invert: flip the sign of the gain
      if (ch.phaseInvert) effectiveGain = -effectiveGain;
    } else {
      effectiveGain = 0.0;
    }

    final gainParam = ch.gainNode.getProperty('gain'.toJS) as JSObject;
    // Cancel any pending ramps to avoid conflicts
    gainParam.callMethod('cancelScheduledValues'.toJS, _now.toJS);
    gainParam.callMethod(
      'setTargetAtTime'.toJS,
      effectiveGain.toJS,
      _now.toJS,
      _gainSmooth.toJS,
    );
  }

  /// Update solo state for all channels
  void _updateSoloState() {
    _anyOscSolo = _channels.values.any((ch) => ch.solo);
    for (final ch in _channels.values) {
      _updateChannelGain(ch);
    }
  }

  /// Update master gain (play/stop, volume, mute)
  void _updateMasterGain() {
    if (_masterGainNode == null) return;

    double gain;
    if (!_isPlaying || _masterMuted) {
      gain = 0.0;
    } else {
      gain = _masterVolume * _masterVolume; // vol² curve
    }

    final gainParam = _masterGainNode!.getProperty('gain'.toJS) as JSObject;
    gainParam.callMethod('cancelScheduledValues'.toJS, _now.toJS);
    gainParam.callMethod(
      'setTargetAtTime'.toJS,
      gain.toJS,
      _now.toJS,
      _masterSmooth.toJS,
    );
  }

  /// Waveform index → Web Audio API type string
  String _waveformName(int waveform) {
    switch (waveform) {
      case 0:
        return 'sine';
      case 1:
        return 'square';
      case 2:
        return 'triangle';
      case 3:
        return 'sawtooth';
      default:
        return 'sine';
    }
  }
}
