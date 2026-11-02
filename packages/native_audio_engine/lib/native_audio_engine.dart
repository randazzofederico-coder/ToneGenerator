// Re-export LiveMixer for convenient use
export 'live_mixer.dart';

import 'native_audio_engine_platform_interface.dart';

class NativeAudioEngine {
  Future<String?> getPlatformVersion() {
    return NativeAudioEnginePlatform.instance.getPlatformVersion();
  }
}
