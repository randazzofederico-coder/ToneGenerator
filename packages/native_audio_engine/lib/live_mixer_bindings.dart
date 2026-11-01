import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// --- Type definitions ---

typedef LiveMixerCreateC = Pointer<Void> Function(Int32);
typedef LiveMixerCreateDart = Pointer<Void> Function(int);

typedef LiveMixerDestroyC = Void Function(Pointer<Void>);
typedef LiveMixerDestroyDart = void Function(Pointer<Void>);

// Oscillator API
typedef OscAddC = Void Function(Pointer<Void>, Pointer<Utf8>, Double, Int32);
typedef OscAddDart = void Function(Pointer<Void>, Pointer<Utf8>, double, int);

typedef OscRemoveC = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef OscRemoveDart = void Function(Pointer<Void>, Pointer<Utf8>);

typedef OscSetFreqC = Void Function(Pointer<Void>, Pointer<Utf8>, Double);
typedef OscSetFreqDart = void Function(Pointer<Void>, Pointer<Utf8>, double);

typedef OscSetWaveformC = Void Function(Pointer<Void>, Pointer<Utf8>, Int32);
typedef OscSetWaveformDart = void Function(Pointer<Void>, Pointer<Utf8>, int);

typedef OscSetVolumeC = Void Function(Pointer<Void>, Pointer<Utf8>, Float);
typedef OscSetVolumeDart = void Function(Pointer<Void>, Pointer<Utf8>, double);

typedef OscSetPanC = Void Function(Pointer<Void>, Pointer<Utf8>, Float);
typedef OscSetPanDart = void Function(Pointer<Void>, Pointer<Utf8>, double);

typedef OscSetMuteC = Void Function(Pointer<Void>, Pointer<Utf8>, Bool);
typedef OscSetMuteDart = void Function(Pointer<Void>, Pointer<Utf8>, bool);

typedef OscSetSoloC = Void Function(Pointer<Void>, Pointer<Utf8>, Bool);
typedef OscSetSoloDart = void Function(Pointer<Void>, Pointer<Utf8>, bool);

typedef OscSetPhaseInvertC = Void Function(Pointer<Void>, Pointer<Utf8>, Bool);
typedef OscSetPhaseInvertDart = void Function(Pointer<Void>, Pointer<Utf8>, bool);

// Master
typedef SetMasterVolumeC = Void Function(Pointer<Void>, Float);
typedef SetMasterVolumeDart = void Function(Pointer<Void>, double);

typedef SetMasterMuteC = Void Function(Pointer<Void>, Bool);
typedef SetMasterMuteDart = void Function(Pointer<Void>, bool);

// Playback
typedef PlaybackVoidC = Void Function(Pointer<Void>);
typedef PlaybackVoidDart = void Function(Pointer<Void>);

typedef ProcessC = Int32 Function(Pointer<Void>, Pointer<Float>, Int32);
typedef ProcessDart = int Function(Pointer<Void>, Pointer<Float>, int);

class LiveMixerBindings {
  late DynamicLibrary _lib;
  
  late LiveMixerCreateDart _create;
  late LiveMixerDestroyDart _destroy;

  // Oscillator
  late OscAddDart _addOscillator;
  late OscRemoveDart _removeOscillator;
  late OscSetFreqDart _setOscFreq;
  late OscSetWaveformDart _setOscWaveform;
  late OscSetVolumeDart _setOscVolume;
  late OscSetPanDart _setOscPan;
  late OscSetMuteDart _setOscMute;
  late OscSetSoloDart _setOscSolo;
  late OscSetPhaseInvertDart _setOscPhaseInvert;

  // Master
  late SetMasterVolumeDart _setMasterVolume;
  late SetMasterMuteDart _setMasterMute;

  // Playback
  late PlaybackVoidDart _start;
  late PlaybackVoidDart _stop;
  late ProcessDart _process;

  LiveMixerBindings() {
    if (Platform.isWindows) {
      _lib = DynamicLibrary.open('native_audio_engine_plugin.dll');
    } else if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libnative_audio_engine_plugin.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process(); 
    } else if (Platform.isMacOS) {
      _lib = DynamicLibrary.open('native_audio_engine_plugin.framework/native_audio_engine_plugin');
    } else {
      try {
        _lib = DynamicLibrary.process();
      } catch (_) {
        throw UnsupportedError('Unsupported platform or library not found');
      }
    }

    _create = _lib.lookupFunction<LiveMixerCreateC, LiveMixerCreateDart>('live_mixer_create');
    _destroy = _lib.lookupFunction<LiveMixerDestroyC, LiveMixerDestroyDart>('live_mixer_destroy');

    // Oscillator bindings
    _addOscillator = _lib.lookupFunction<OscAddC, OscAddDart>('live_mixer_add_oscillator');
    _removeOscillator = _lib.lookupFunction<OscRemoveC, OscRemoveDart>('live_mixer_remove_oscillator');
    _setOscFreq = _lib.lookupFunction<OscSetFreqC, OscSetFreqDart>('live_mixer_set_oscillator_freq');
    _setOscWaveform = _lib.lookupFunction<OscSetWaveformC, OscSetWaveformDart>('live_mixer_set_oscillator_waveform');
    _setOscVolume = _lib.lookupFunction<OscSetVolumeC, OscSetVolumeDart>('live_mixer_set_oscillator_volume');
    _setOscPan = _lib.lookupFunction<OscSetPanC, OscSetPanDart>('live_mixer_set_oscillator_pan');
    _setOscMute = _lib.lookupFunction<OscSetMuteC, OscSetMuteDart>('live_mixer_set_oscillator_mute');
    _setOscSolo = _lib.lookupFunction<OscSetSoloC, OscSetSoloDart>('live_mixer_set_oscillator_solo');
    _setOscPhaseInvert = _lib.lookupFunction<OscSetPhaseInvertC, OscSetPhaseInvertDart>('live_mixer_set_oscillator_phase_invert');

    // Master bindings
    _setMasterVolume = _lib.lookupFunction<SetMasterVolumeC, SetMasterVolumeDart>('live_mixer_set_master_volume');
    _setMasterMute = _lib.lookupFunction<SetMasterMuteC, SetMasterMuteDart>('live_mixer_set_master_mute');

    // Playback bindings
    _start = _lib.lookupFunction<PlaybackVoidC, PlaybackVoidDart>('live_mixer_start');
    _stop = _lib.lookupFunction<PlaybackVoidC, PlaybackVoidDart>('live_mixer_stop');
    _process = _lib.lookupFunction<ProcessC, ProcessDart>('live_mixer_process');
  }

  Pointer<Void> create(int sampleRate) => _create(sampleRate);
  void destroy(Pointer<Void> handle) => _destroy(handle);

  // --- Oscillator ---
  void addOscillator(Pointer<Void> mixer, String id, double freq, int waveform) {
    final idPtr = id.toNativeUtf8();
    _addOscillator(mixer, idPtr, freq, waveform);
    calloc.free(idPtr);
  }

  void removeOscillator(Pointer<Void> mixer, String id) {
    final idPtr = id.toNativeUtf8();
    _removeOscillator(mixer, idPtr);
    calloc.free(idPtr);
  }

  void setOscillatorFreq(Pointer<Void> mixer, String id, double freq) {
    final idPtr = id.toNativeUtf8();
    _setOscFreq(mixer, idPtr, freq);
    calloc.free(idPtr);
  }

  void setOscillatorWaveform(Pointer<Void> mixer, String id, int waveform) {
    final idPtr = id.toNativeUtf8();
    _setOscWaveform(mixer, idPtr, waveform);
    calloc.free(idPtr);
  }

  void setOscillatorVolume(Pointer<Void> mixer, String id, double volume) {
    final idPtr = id.toNativeUtf8();
    _setOscVolume(mixer, idPtr, volume);
    calloc.free(idPtr);
  }

  void setOscillatorPan(Pointer<Void> mixer, String id, double pan) {
    final idPtr = id.toNativeUtf8();
    _setOscPan(mixer, idPtr, pan);
    calloc.free(idPtr);
  }

  void setOscillatorMute(Pointer<Void> mixer, String id, bool muted) {
    final idPtr = id.toNativeUtf8();
    _setOscMute(mixer, idPtr, muted);
    calloc.free(idPtr);
  }

  void setOscillatorSolo(Pointer<Void> mixer, String id, bool solo) {
    final idPtr = id.toNativeUtf8();
    _setOscSolo(mixer, idPtr, solo);
    calloc.free(idPtr);
  }

  void setOscillatorPhaseInvert(Pointer<Void> mixer, String id, bool invert) {
    final idPtr = id.toNativeUtf8();
    _setOscPhaseInvert(mixer, idPtr, invert);
    calloc.free(idPtr);
  }

  // --- Master ---
  void setMasterVolume(Pointer<Void> mixer, double volume) => _setMasterVolume(mixer, volume);
  void setMasterMute(Pointer<Void> mixer, bool muted) => _setMasterMute(mixer, muted);

  // --- Playback ---
  void start(Pointer<Void> mixer) => _start(mixer);
  void stop(Pointer<Void> mixer) => _stop(mixer);
  int process(Pointer<Void> mixer, Pointer<Float> output, int frames) => _process(mixer, output, frames);
}
