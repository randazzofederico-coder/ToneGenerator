#ifndef LIVE_MIXER_H
#define LIVE_MIXER_H

#include <vector>
#include <map>
#include <mutex>
#include <algorithm>
#include <cstring>
#include <cmath>
#include <atomic>
#include <string>

#include "miniaudio.h"

#if defined(_WIN32)
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

class LiveMixer {
public:
    LiveMixer(int sampleRate);
    ~LiveMixer();

    // --- OSCILLATOR CHANNELS ---
    void addOscillator(const char* id, double freq, int waveform);
    void removeOscillator(const char* id);
    void setOscillatorFreq(const char* id, double freq);
    void setOscillatorWaveform(const char* id, int waveform);
    void setOscillatorVolume(const char* id, float vol);
    void setOscillatorPan(const char* id, float pan);
    void setOscillatorMute(const char* id, bool muted);
    void setOscillatorSolo(const char* id, bool solo);
    void setOscillatorPhaseInvert(const char* id, bool invert);

    // Global Settings
    void setMasterVolume(float volume);
    void setMasterMute(bool muted);
    
    // --- NATIVE OUTPUT CONTROL ---
    void startPlayback();
    void stopPlayback();

    // Audio Processing
    int process(float* outputBuffer, int numFrames);

private:
    // Oscillator waveform enum
    // 0=sine, 1=square, 2=triangle, 3=sawtooth
    struct OscillatorChannel {
        std::string id;
        double frequency = 440.0;
        double targetFrequency = 440.0;  // smoothing target
        int waveform = 0;
        float volume = 0.3f;
        float targetVolume = 0.3f;       // smoothing target
        float pan = 0.0f;
        float targetPan = 0.0f;          // smoothing target
        bool muted = false;
        bool solo = false;
        bool phaseInvert = false;
        double phase = 0.0; // running phase [0, 2π)
        float envelope = 1.0f;
    };

    std::vector<OscillatorChannel> _oscillators;
    bool _anyOscSolo = false;
    void _updateAnyOscSolo();

    std::mutex _mutex;
    bool _isPlaying = false;

    // Envelopes for click-prevention
    float _masterEnvelope = 1.0f;
    float _targetEnvelope = 1.0f;
    
    // Master Volume (with smoothing)
    float _masterVolume = 1.0f;
    float _targetMasterVolume = 1.0f;
    bool _masterMuted = false;
    
    int _engineSampleRate = 44100;

    // Internal mixing logic
    void _mixInternal(float* outputBuffer, int numFrames);

    // --- MINIAUDIO ---
    ma_device _device;
    bool _deviceInit = false;

    static void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount);
};

extern "C" {
    EXPORT void* live_mixer_create(int sampleRate);
    EXPORT void live_mixer_destroy(void* mixer);

    // Oscillator API
    EXPORT void live_mixer_add_oscillator(void* mixer, const char* id, double freq, int waveform);
    EXPORT void live_mixer_remove_oscillator(void* mixer, const char* id);
    EXPORT void live_mixer_set_oscillator_freq(void* mixer, const char* id, double freq);
    EXPORT void live_mixer_set_oscillator_waveform(void* mixer, const char* id, int waveform);
    EXPORT void live_mixer_set_oscillator_volume(void* mixer, const char* id, float vol);
    EXPORT void live_mixer_set_oscillator_pan(void* mixer, const char* id, float pan);
    EXPORT void live_mixer_set_oscillator_mute(void* mixer, const char* id, bool muted);
    EXPORT void live_mixer_set_oscillator_solo(void* mixer, const char* id, bool solo);
    EXPORT void live_mixer_set_oscillator_phase_invert(void* mixer, const char* id, bool invert);

    // Master
    EXPORT void live_mixer_set_master_volume(void* mixer, float volume);
    EXPORT void live_mixer_set_master_mute(void* mixer, bool muted);

    // Playback
    EXPORT void live_mixer_start(void* mixer);
    EXPORT void live_mixer_stop(void* mixer);
    EXPORT int live_mixer_process(void* mixer, float* output, int frames);
}

#endif // LIVE_MIXER_H
