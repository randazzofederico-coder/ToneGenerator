// AudioWorkletProcessor for Tone Generator — WebAssembly/C++ bridge
// Runs on the audio rendering thread for glitch-free synthesis.

class LiveMixerWorkletProcessor extends AudioWorkletProcessor {
    constructor(options) {
        super();
        this.module = null;
        this.mixerHandle = null;
        this.isProcessing = false;
        this.commandQueue = [];

        this.port.onmessage = async (event) => {
            const data = event.data;
            
            if (data.type === 'init') {
                // Emscripten may require crypto for random numbers
                if (typeof crypto === 'undefined') {
                    globalThis.crypto = {
                        getRandomValues: function(arr) {
                            for (let i = 0; i < arr.length; i++) {
                                arr[i] = Math.floor(Math.random() * 256);
                            }
                        }
                    };
                }

                const wasmBinary = data.wasmBinary;
                try {
                    this.module = await LiveMixerModule({ wasmBinary: wasmBinary });
                    this.mixerHandle = this.module._live_mixer_create(sampleRate);
                    this.port.postMessage({ type: 'ready' });
                } catch (e) {
                    console.error("AudioWorklet failed to load Wasm:", e);
                }
            } else if (data.type === 'start') {
                this.isProcessing = true;
                if (this.module && this.mixerHandle) {
                    this.module._live_mixer_start(this.mixerHandle);
                }
            } else if (data.type === 'stop') {
                this.isProcessing = false;
                if (this.module && this.mixerHandle) {
                    this.module._live_mixer_stop(this.mixerHandle);
                }
            } else if (data.type === 'cmd') {
                this.commandQueue.push(data);
            }
        };
    }
    
    _allocateString(str) {
        return this.module.allocateUTF8(str);
    }
    
    _processCommand(data) {
        const handle = this.mixerHandle;
        const m = this.module;
        if (!handle || !m) return;

        switch(data.cmd) {
            // --- Oscillator commands ---
            case 'addOscillator': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_add_oscillator(handle, idPtr, data.freq, data.waveform);
                m._free(idPtr);
                break;
            }
            case 'removeOscillator': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_remove_oscillator(handle, idPtr);
                m._free(idPtr);
                break;
            }
            case 'setOscillatorFreq': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_set_oscillator_freq(handle, idPtr, data.freq);
                m._free(idPtr);
                break;
            }
            case 'setOscillatorWaveform': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_set_oscillator_waveform(handle, idPtr, data.waveform);
                m._free(idPtr);
                break;
            }
            case 'setOscillatorVolume': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_set_oscillator_volume(handle, idPtr, data.volume);
                m._free(idPtr);
                break;
            }
            case 'setOscillatorPan': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_set_oscillator_pan(handle, idPtr, data.pan);
                m._free(idPtr);
                break;
            }
            case 'setOscillatorMute': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_set_oscillator_mute(handle, idPtr, data.muted);
                m._free(idPtr);
                break;
            }
            case 'setOscillatorSolo': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_set_oscillator_solo(handle, idPtr, data.solo);
                m._free(idPtr);
                break;
            }
            case 'setOscillatorPhaseInvert': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_set_oscillator_phase_invert(handle, idPtr, data.invert);
                m._free(idPtr);
                break;
            }

            // --- Master ---
            case 'setMasterVolume':
                m._live_mixer_set_master_volume(handle, data.volume);
                break;
            case 'setMasterMute':
                m._live_mixer_set_master_mute(handle, data.muted);
                break;

            // --- Lifecycle ---
            case 'dispose':
                m._live_mixer_destroy(handle);
                this.mixerHandle = null;
                break;
        }
    }

    process(inputs, outputs, parameters) {
        // Execute pending commands from Dart
        while (this.commandQueue.length > 0) {
            const cmd = this.commandQueue.shift();
            this._processCommand(cmd);
        }

        if (!this.module || !this.mixerHandle || !this.isProcessing) {
            for (let channel = 0; channel < outputs[0].length; ++channel) {
                outputs[0][channel].fill(0.0);
            }
            return true;
        }

        const outputBuffer = outputs[0];
        if (!outputBuffer || outputBuffer.length === 0) return true;
        const framesToProcess = outputBuffer[0].length;
        
        let bytesToAlloc = framesToProcess * 2 * 4; // stereo * float32
        let outputPtr = this.module._malloc(bytesToAlloc);
        
        // C++ oscillator synthesis on audio thread
        let framesWritten = this.module._live_mixer_process(this.mixerHandle, outputPtr, framesToProcess);
        
        if (framesWritten > 0) {
            let leftChannel = outputBuffer[0];
            let rightChannel = outputBuffer.length > 1 ? outputBuffer[1] : null;
            let heapF32 = this.module.HEAPF32;
            let offset = outputPtr / 4;
            
            for (let i = 0; i < framesWritten; ++i) {
                leftChannel[i] = heapF32[offset + i * 2];
                if (rightChannel) {
                    rightChannel[i] = heapF32[offset + i * 2 + 1];
                }
            }
        } else {
            for (let channel = 0; channel < outputs[0].length; ++channel) {
                outputs[0][channel].fill(0.0);
            }
        }
        
        this.module._free(outputPtr);
        return true;
    }
}

registerProcessor('live-mixer-worklet', LiveMixerWorkletProcessor);
