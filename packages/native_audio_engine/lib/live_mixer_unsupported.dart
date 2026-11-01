class LiveMixer {
  bool isReady = false;

  LiveMixer();

  Future<void> init() async {
    throw UnsupportedError('LiveMixer is not supported on this platform.');
  }

  void dispose() {}

  void addOscillator(String id, double freq, int waveform) {}
  void removeOscillator(String id) {}
  void setOscillatorFreq(String id, double freq) {}
  void setOscillatorWaveform(String id, int waveform) {}
  void setOscillatorVolume(String id, double volume) {}
  void setOscillatorPan(String id, double pan) {}
  void setOscillatorMute(String id, bool muted) {}
  void setOscillatorSolo(String id, bool solo) {}
  void setOscillatorPhaseInvert(String id, bool invert) {}

  void setMasterVolume(double volume) {}
  void setMasterMute(bool muted) {}

  void startPlayback() {}
  void stopPlayback() {}

  int getSampleRate() => 44100;
}
