import 'live_mixer_bindings.dart';
import 'dart:ffi';

class LiveMixer {
  final LiveMixerBindings _bindings = LiveMixerBindings();
  late Pointer<Void> _handle;
  bool _isDisposed = false;

  LiveMixer() {
    _handle = _bindings.create(44100);
  }

  void dispose() {
    if (!_isDisposed) {
      _bindings.destroy(_handle);
      _isDisposed = true;
    }
  }

  // --- Oscillator API ---

  void addOscillator(String id, double freq, int waveform) {
    if (_isDisposed) return;
    _bindings.addOscillator(_handle, id, freq, waveform);
  }

  void removeOscillator(String id) {
    if (_isDisposed) return;
    _bindings.removeOscillator(_handle, id);
  }

  void setOscillatorFreq(String id, double freq) {
    if (_isDisposed) return;
    _bindings.setOscillatorFreq(_handle, id, freq);
  }

  void setOscillatorWaveform(String id, int waveform) {
    if (_isDisposed) return;
    _bindings.setOscillatorWaveform(_handle, id, waveform);
  }

  void setOscillatorVolume(String id, double volume) {
    if (_isDisposed) return;
    _bindings.setOscillatorVolume(_handle, id, volume);
  }

  void setOscillatorPan(String id, double pan) {
    if (_isDisposed) return;
    _bindings.setOscillatorPan(_handle, id, pan);
  }

  void setOscillatorMute(String id, bool muted) {
    if (_isDisposed) return;
    _bindings.setOscillatorMute(_handle, id, muted);
  }

  void setOscillatorSolo(String id, bool solo) {
    if (_isDisposed) return;
    _bindings.setOscillatorSolo(_handle, id, solo);
  }

  void setOscillatorPhaseInvert(String id, bool invert) {
    if (_isDisposed) return;
    _bindings.setOscillatorPhaseInvert(_handle, id, invert);
  }

  // --- Master ---

  void setMasterVolume(double volume) {
    if (_isDisposed) return;
    _bindings.setMasterVolume(_handle, volume);
  }

  void setMasterMute(bool muted) {
    if (_isDisposed) return;
    _bindings.setMasterMute(_handle, muted);
  }

  // --- Playback ---

  void startPlayback() {
    if (_isDisposed) return;
    _bindings.start(_handle);
  }

  void stopPlayback() {
    if (_isDisposed) return;
    _bindings.stop(_handle);
  }

  int getSampleRate() => 44100;

  Future<void> init() async {
    // No async init needed for native — device is created in constructor
  }

  bool get isReady => !_isDisposed;
}
