#include <iostream>

#define MINIAUDIO_IMPLEMENTATION
#include "live_mixer.h"

using namespace std;

// Forward declaration of callback wrapper
void data_callback_wrapper(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    auto mixer = static_cast<LiveMixer*>(pDevice->pUserData);
    if (mixer) {
        mixer->process(static_cast<float*>(pOutput), frameCount);
    }
}

LiveMixer::LiveMixer(int sampleRate) : _engineSampleRate(sampleRate) {
    // initialize miniaudio (Only for desktop/mobile, not WebAssembly since we use AudioWorklet)
#ifndef __EMSCRIPTEN__
    ma_device_config config = ma_device_config_init(ma_device_type_playback);
    config.playback.format   = ma_format_f32;
    config.playback.channels = 2; // Stereo
    config.sampleRate        = _engineSampleRate;
    
    config.periodSizeInMilliseconds = 20; 
    config.periods = 3; 
    
    config.dataCallback      = data_callback_wrapper;
    config.pUserData         = this;

    if (ma_device_init(NULL, &config, &_device) != MA_SUCCESS) {
        std::cerr << "Failed to initialize playback device." << std::endl;
        _deviceInit = false;
    } else {
        _deviceInit = true;
        if (ma_device_start(&_device) != MA_SUCCESS) {
            std::cerr << "Failed to start playback device." << std::endl;
        }
    }
#else
    _deviceInit = false;
    _isPlaying = false;
#endif
}

LiveMixer::~LiveMixer() {
#ifndef __EMSCRIPTEN__
    if (_deviceInit) {
        ma_device_uninit(&_device);
    }
#endif
}

void LiveMixer::startPlayback() {
    std::lock_guard<std::mutex> lock(_mutex);
    _masterEnvelope = 0.0f;
    _targetEnvelope = 1.0f;
    _isPlaying = true;
}

void LiveMixer::stopPlayback() {
    std::lock_guard<std::mutex> lock(_mutex);
    _isPlaying = false;
}

// --- OSCILLATOR MANAGEMENT ---

void LiveMixer::_updateAnyOscSolo() {
    _anyOscSolo = false;
    for (const auto& osc : _oscillators) {
        if (osc.solo) {
            _anyOscSolo = true;
            break;
        }
    }
}

void LiveMixer::addOscillator(const char* id, double freq, int waveform) {
    if (!id) return;
    std::lock_guard<std::mutex> lock(_mutex);
    
    // Check if oscillator with this id already exists
    for (auto& osc : _oscillators) {
        if (osc.id == id) {
            osc.targetFrequency = freq;
            osc.frequency = freq;
            osc.waveform = waveform;
            osc.phase = 0.0;
            return;
        }
    }
    
    OscillatorChannel osc;
    osc.id = id;
    osc.frequency = freq;
    osc.targetFrequency = freq;
    osc.waveform = waveform;
    osc.phase = 0.0;
    osc.volume = 0.3f;
    osc.targetVolume = 0.3f;
    osc.pan = 0.0f;
    osc.targetPan = 0.0f;
    osc.muted = false;
    osc.solo = false;
    osc.phaseInvert = false;
    osc.envelope = 1.0f;
    _oscillators.push_back(osc);
}

void LiveMixer::removeOscillator(const char* id) {
    if (!id) return;
    std::lock_guard<std::mutex> lock(_mutex);
    _oscillators.erase(
        std::remove_if(_oscillators.begin(), _oscillators.end(),
            [id](const OscillatorChannel& osc) { return osc.id == id; }),
        _oscillators.end());
    _updateAnyOscSolo();
}

void LiveMixer::setOscillatorFreq(const char* id, double freq) {
    if (!id) return;
    std::lock_guard<std::mutex> lock(_mutex);
    for (auto& osc : _oscillators) {
        if (osc.id == id) {
            osc.targetFrequency = freq;
            break;
        }
    }
}

void LiveMixer::setOscillatorWaveform(const char* id, int waveform) {
    if (!id) return;
    std::lock_guard<std::mutex> lock(_mutex);
    for (auto& osc : _oscillators) {
        if (osc.id == id) {
            osc.waveform = waveform;
            break;
        }
    }
}

void LiveMixer::setOscillatorVolume(const char* id, float vol) {
    if (!id) return;
    std::lock_guard<std::mutex> lock(_mutex);
    for (auto& osc : _oscillators) {
        if (osc.id == id) {
            osc.targetVolume = vol;
            break;
        }
    }
}

void LiveMixer::setOscillatorPan(const char* id, float pan) {
    if (!id) return;
    std::lock_guard<std::mutex> lock(_mutex);
    for (auto& osc : _oscillators) {
        if (osc.id == id) {
            osc.targetPan = pan;
            break;
        }
    }
}

void LiveMixer::setOscillatorMute(const char* id, bool muted) {
    if (!id) return;
    std::lock_guard<std::mutex> lock(_mutex);
    for (auto& osc : _oscillators) {
        if (osc.id == id) {
            osc.muted = muted;
            break;
        }
    }
}

void LiveMixer::setOscillatorSolo(const char* id, bool solo) {
    if (!id) return;
    std::lock_guard<std::mutex> lock(_mutex);
    for (auto& osc : _oscillators) {
        if (osc.id == id) {
            osc.solo = solo;
            _updateAnyOscSolo();
            break;
        }
    }
}

void LiveMixer::setOscillatorPhaseInvert(const char* id, bool invert) {
    if (!id) return;
    std::lock_guard<std::mutex> lock(_mutex);
    for (auto& osc : _oscillators) {
        if (osc.id == id) {
            osc.phaseInvert = invert;
            break;
        }
    }
}

void LiveMixer::setMasterVolume(float volume) {
    std::lock_guard<std::mutex> lock(_mutex);
    _targetMasterVolume = volume;
}

void LiveMixer::setMasterMute(bool muted) {
    std::lock_guard<std::mutex> lock(_mutex);
    _masterMuted = muted;
}

// --- MIXING ---

void LiveMixer::_mixInternal(float* outputBuffer, int numFrames) {
    // Assumes mutex is ALREADY LOCKED by caller (process)
    
    if (_oscillators.empty()) {
        memset(outputBuffer, 0, numFrames * 2 * sizeof(float));
        return;
    }
    
    memset(outputBuffer, 0, numFrames * 2 * sizeof(float));
    
    // Smoothing coefficients
    float envelopeStep = 1.0f / ((float)_engineSampleRate * 0.02f); // 20ms for mute/solo
    
    // Exponential smoothing for freq/vol/pan (~5ms time constant)
    // coeff = 1.0 - exp(-1.0 / (sampleRate * timeConstant))
    double freqSmoothCoeff = 1.0 - exp(-1.0 / ((double)_engineSampleRate * 0.005)); // 5ms
    float paramSmoothCoeff = (float)(1.0 - exp(-1.0 / ((double)_engineSampleRate * 0.010))); // 10ms
    float masterSmoothCoeff = (float)(1.0 - exp(-1.0 / ((double)_engineSampleRate * 0.020))); // 20ms
    
    for (int i = 0; i < numFrames; i++) {
        float leftSum = 0.0f;
        float rightSum = 0.0f;
        
        // --- MASTER ENVELOPE (fade-in on start) ---
        if (_masterEnvelope < _targetEnvelope) {
            _masterEnvelope += envelopeStep;
            if (_masterEnvelope > _targetEnvelope) _masterEnvelope = _targetEnvelope;
        } else if (_masterEnvelope > _targetEnvelope) {
            _masterEnvelope -= envelopeStep;
            if (_masterEnvelope < _targetEnvelope) _masterEnvelope = _targetEnvelope;
        }
        
        // --- SMOOTH MASTER VOLUME ---
        _masterVolume += (_targetMasterVolume - _masterVolume) * masterSmoothCoeff;
        
        // --- OSCILLATOR CHANNELS ---
        for (auto& osc : _oscillators) {
            // --- SMOOTH FREQUENCY (exponential interpolation for glide) ---
            osc.frequency += (osc.targetFrequency - osc.frequency) * freqSmoothCoeff;
            
            // --- SMOOTH VOLUME ---
            osc.volume += (osc.targetVolume - osc.volume) * paramSmoothCoeff;
            
            // --- SMOOTH PAN ---
            osc.pan += (osc.targetPan - osc.pan) * paramSmoothCoeff;
            
            // Solo/Mute logic
            bool playOsc = true;
            if (_anyOscSolo) {
                playOsc = osc.solo;
            } else {
                playOsc = !osc.muted;
            }
            
            // Smooth envelope for click-free mute/solo transitions
            float targetEnv = playOsc ? 1.0f : 0.0f;
            if (osc.envelope < targetEnv) {
                osc.envelope += envelopeStep;
                if (osc.envelope > targetEnv) osc.envelope = targetEnv;
            } else if (osc.envelope > targetEnv) {
                osc.envelope -= envelopeStep;
                if (osc.envelope < targetEnv) osc.envelope = targetEnv;
            }
            
            // Phase increment uses SMOOTHED frequency
            double phaseIncrement = 2.0 * M_PI * osc.frequency / _engineSampleRate;
            
            if (osc.envelope > 0.0001f) {
                // Generate sample based on waveform type
                double sample = 0.0;
                double normalizedPhase = osc.phase / (2.0 * M_PI); // [0, 1)
                
                switch (osc.waveform) {
                    case 0: // Sine
                        sample = sin(osc.phase);
                        break;
                    case 1: // Square
                        sample = osc.phase < M_PI ? 1.0 : -1.0;
                        break;
                    case 2: // Triangle
                        sample = 2.0 * fabs(2.0 * normalizedPhase - 1.0) - 1.0;
                        break;
                    case 3: // Sawtooth
                        sample = 2.0 * normalizedPhase - 1.0;
                        break;
                    default:
                        sample = sin(osc.phase);
                        break;
                }
                
                // Phase inversion
                if (osc.phaseInvert) sample = -sample;
                
                // Pan (uses SMOOTHED pan value)
                float lGain = 1.0f;
                float rGain = 1.0f;
                if (osc.pan > 0.0f) lGain = 1.0f - osc.pan;
                else if (osc.pan < 0.0f) rGain = 1.0f + osc.pan;
                
                // Vol² curve applied to SMOOTHED volume
                float effectiveVol = osc.volume * osc.volume;
                float finalSample = (float)sample * effectiveVol * osc.envelope;
                leftSum += finalSample * lGain;
                rightSum += finalSample * rGain;
            }
            
            // Advance phase
            osc.phase += phaseIncrement;
            if (osc.phase >= 2.0 * M_PI) osc.phase -= 2.0 * M_PI;
        }
        
        // Apply SMOOTHED master volume (quadratic curve) and envelope
        float effectiveMaster = _masterVolume * _masterVolume;
        float masterGain = _masterEnvelope * effectiveMaster;
        if (_masterMuted) masterGain = 0.0f;
        
        float outL = leftSum * masterGain;
        float outR = rightSum * masterGain;
        
        // Soft clipping (tanh) to prevent harsh digital distortion
        outputBuffer[i * 2] = tanhf(outL);
        outputBuffer[i * 2 + 1] = tanhf(outR);
    }
}

int LiveMixer::process(float* outputBuffer, int numFrames) {
    std::lock_guard<std::mutex> lock(_mutex);
    
    if (!_isPlaying) {
        memset(outputBuffer, 0, numFrames * 2 * sizeof(float));
        _masterEnvelope = 0.0f;
        return numFrames;
    }
    
    _mixInternal(outputBuffer, numFrames);
    return numFrames;
}

// --- C API WRAPPERS ---

extern "C" {
    EXPORT void* live_mixer_create(int sampleRate) {
        return new LiveMixer(sampleRate);
    }
    
    EXPORT void live_mixer_destroy(void* mixer) {
        if (mixer) delete static_cast<LiveMixer*>(mixer);
    }

    // --- Oscillator API ---
    EXPORT void live_mixer_add_oscillator(void* mixer, const char* id, double freq, int waveform) {
        if (mixer) static_cast<LiveMixer*>(mixer)->addOscillator(id, freq, waveform);
    }

    EXPORT void live_mixer_remove_oscillator(void* mixer, const char* id) {
        if (mixer) static_cast<LiveMixer*>(mixer)->removeOscillator(id);
    }

    EXPORT void live_mixer_set_oscillator_freq(void* mixer, const char* id, double freq) {
        if (mixer) static_cast<LiveMixer*>(mixer)->setOscillatorFreq(id, freq);
    }

    EXPORT void live_mixer_set_oscillator_waveform(void* mixer, const char* id, int waveform) {
        if (mixer) static_cast<LiveMixer*>(mixer)->setOscillatorWaveform(id, waveform);
    }

    EXPORT void live_mixer_set_oscillator_volume(void* mixer, const char* id, float vol) {
        if (mixer) static_cast<LiveMixer*>(mixer)->setOscillatorVolume(id, vol);
    }

    EXPORT void live_mixer_set_oscillator_pan(void* mixer, const char* id, float pan) {
        if (mixer) static_cast<LiveMixer*>(mixer)->setOscillatorPan(id, pan);
    }

    EXPORT void live_mixer_set_oscillator_mute(void* mixer, const char* id, bool muted) {
        if (mixer) static_cast<LiveMixer*>(mixer)->setOscillatorMute(id, muted);
    }

    EXPORT void live_mixer_set_oscillator_solo(void* mixer, const char* id, bool solo) {
        if (mixer) static_cast<LiveMixer*>(mixer)->setOscillatorSolo(id, solo);
    }

    EXPORT void live_mixer_set_oscillator_phase_invert(void* mixer, const char* id, bool invert) {
        if (mixer) static_cast<LiveMixer*>(mixer)->setOscillatorPhaseInvert(id, invert);
    }

    // --- Master ---
    EXPORT void live_mixer_set_master_volume(void* mixer, float volume) {
        if (mixer) static_cast<LiveMixer*>(mixer)->setMasterVolume(volume);
    }

    EXPORT void live_mixer_set_master_mute(void* mixer, bool muted) {
        if (mixer) static_cast<LiveMixer*>(mixer)->setMasterMute(muted);
    }

    // --- Playback ---
    EXPORT void live_mixer_start(void* mixer) {
        if (mixer) static_cast<LiveMixer*>(mixer)->startPlayback();
    }

    EXPORT void live_mixer_stop(void* mixer) {
        if (mixer) static_cast<LiveMixer*>(mixer)->stopPlayback();
    }

    EXPORT int live_mixer_process(void* mixer, float* output, int frames) {
        if (mixer) return static_cast<LiveMixer*>(mixer)->process(output, frames);
        return 0;
    }
}
