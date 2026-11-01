# Tone Generator

Generador de frecuencias multi-canal con síntesis de ondas en tiempo real.

Aplicación profesional para generar tonos de prueba, calibrar equipos de audio, y explorar frecuencias. Soporta múltiples canales simultáneos con control independiente de frecuencia, volumen, paneo y forma de onda.

## Características

### 🎛️ Multi-canal
- Hasta 8 canales simultáneos con colores distintivos
- Control independiente de frecuencia, volumen y paneo por canal
- Mute (M), Solo (S) e inversión de fase (Ø) por canal
- Master Volume global

### 🎵 Síntesis de ondas
- **Senoidal** — tono puro
- **Cuadrada** — armónicos impares
- **Triangular** — armónicos impares, menor amplitud
- **Diente de sierra** — todos los armónicos

### 🎹 Piano interactivo
- Teclado de piano en la parte inferior con todas las octavas
- Muestra indicadores de color por cada canal activo
- Selección de canal para editar la nota desde el piano
- Scroll lateral para recorrer todo el registro

### 🔧 Control de frecuencia
- **Slider logarítmico** (1 Hz – 20.154 Hz)
- **Drag vertical** sobre el display de Hz para ajuste fino (0.1 Hz/px)
- **Doble-tap** en el display para edición manual directa
- **×½ / ×2** para saltar octavas
- Muestra la nota musical más cercana (con prefijo `~` si no es temperada)

### ⚙️ Ajustes
- **Tamaño de interfaz** configurable (70% – 130%)
- Información de sesión y verificación
- Advertencia de seguridad auditiva

### 🔐 Autenticación
- Google Sign-In y email/contraseña
- Verificación de permisos vía Firestore
- Acceso offline con cache local (30 días)
- Período de prueba de 30 días
- Banners de trial y expiración

## Arquitectura

### Motor de Audio

| Plataforma | Implementación |
|---|---|
| **Web** | Web Audio API nativo (`OscillatorNode`, `GainNode`, `StereoPannerNode`) con `setTargetAtTime()` para transiciones suaves |
| **Android** | Oboe (C++) vía FFI |
| **Windows** | WASAPI (C++) vía FFI |

El motor web utiliza nodos nativos del Web Audio API para lograr cambios de parámetros *sample-accurate*, eliminando el *stepping* audible que produce `postMessage` a un AudioWorklet.

### Estructura del Proyecto

```
lib/
├── main.dart                          # Entry point, providers, MaterialApp
├── firebase_options.dart              # Firebase config
├── auth/
│   ├── auth_gate.dart                 # Auth flow + permission checker
│   ├── auth_repository.dart           # Permission cache (SharedPreferences)
│   ├── login_screen.dart              # Login/registro
│   └── onboarding_screen.dart         # Creación de perfil
├── models/
│   ├── channel_model.dart             # ToneChannel, Waveform, channelColor()
│   └── permission_cache.dart          # Cache de permisos offline
├── providers/
│   ├── tone_generator_provider.dart   # Estado de canales, playback, mixer
│   └── settings_provider.dart         # UI scale, disclaimer
├── screens/
│   ├── tone_generator_screen.dart     # Pantalla principal
│   └── settings_screen.dart           # Ajustes
├── theme/
│   └── ui_scale.dart                  # Sistema de escalado dimensional
└── widgets/
    ├── channel_card.dart              # Card de canal (2 filas)
    ├── disclaimer_gate.dart           # Advertencia de seguridad
    ├── mini_knob.dart                 # Knob rotativo compacto
    └── piano_keyboard.dart            # Teclado de piano global

packages/
└── native_audio_engine/               # Plugin de audio nativo
    ├── lib/
    │   ├── native_audio_engine.dart   # API pública
    │   └── live_mixer_web.dart        # Implementación Web Audio API
    ├── src/                           # C++ (Oboe/WASAPI)
    ├── android/                       # Plugin Android
    └── windows/                       # Plugin Windows
```

### Sistema UIScale

Todas las dimensiones de la interfaz derivan de un `scaleFactor` configurable:

```dart
class UIScale {
  final double scaleFactor; // 0.7 – 1.3

  double get badgeSize => 22 * scaleFactor;
  double get chipSize => 22 * scaleFactor;
  double get knobDiameter => 26 * scaleFactor;
  // ... etc
}
```

El factor se persiste en SharedPreferences y se aplica reactivamente via `Consumer2<ToneGeneratorProvider, SettingsProvider>`.

## Firestore

### Campos utilizados

| Colección | Campo | Uso |
|---|---|---|
| `usuarios/{uid}` | `suscripciones_apps.tone_generator` | Acceso habilitado |
| `usuarios/{uid}` | `trial_tone_generator_inicio` | Inicio del trial |
| `usuarios/{uid}` | `rol` | Rol del usuario |
| `consultas_web` | (documentos) | Notificaciones al admin |

## Requisitos

- Flutter SDK >= 3.10.4
- Firebase project configurado con Auth + Firestore
- Para Android: SHA-1 y SHA-256 registrados en Firebase

## Desarrollo

```bash
# Debug en Chrome
flutter run -d chrome

# Debug en Android
flutter run

# El motor nativo (C++/FFI) no requiere recompilación para cambios web
```

## Seguridad Auditiva

> ⚠️ **Podés dañar tu audición o tus parlantes si reproducís tonos a volúmenes extremos.**
>
> Las personas no escuchan bien por debajo de 20 Hz ni por encima de 10.000 Hz. Si subís el volumen para compensar, podrías exponerte a niveles dañinos. Encontrá un nivel cómodo a 1.000 Hz y no lo superes demasiado.

## Licencia

Uso privado. Todos los derechos reservados.
