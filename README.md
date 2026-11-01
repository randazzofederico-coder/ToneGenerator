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
- **App libre (estado actual)** — `main.dart` abre directo `DisclaimerGate(child: ToneGeneratorScreen())`. El `AuthGate` (Google Sign-In, email/contraseña, permisos vía Firestore, cache offline de 30 días, trial) se conserva en `lib/auth/` para reactivarlo en el futuro
- El único uso de Auth hoy es el **login anónimo** al compartir sesiones

### 📚 Biblioteca de sesiones
- **Sesión** = canales (frecuencia, onda, volumen, paneo, M/S/Ø) + Master Volume
- 💾 guarda sobre la sesión abierta (snackbar con *DESHACER*); si no existe pide un nombre. Menú ⋮: *Guardar como…*, *Nueva sesión*, *Biblioteca*, *Compartir sesión*, *Ajustes*
- **Cambios sin guardar** — el nombre en la barra superior se muestra en *cursiva* con `*`. Abrir otra sesión o crear una nueva ofrece *Guardar / Descartar / Cancelar*
- **Biblioteca** (`screens/library_screen.dart`) — búsqueda por nombre; tocar = abrir; menú ⋮: abrir, compartir, duplicar, renombrar, eliminar (confirmación + *DESHACER*). La sesión abierta se marca *Abierta*
- **Estado de trabajo persistente** — lo que está cargado se guarda solo (SharedPreferences, `tone_working_state`) y se restaura al reabrir la app
- **Nunca suena sola** — abrir una sesión (propia o recibida) detiene la reproducción; hay que dar Play

### 🔗 Compartir sesiones (Deep Links)
Mismo diseño que el Metrónomo, en una colección propia.
- **URL** — `https://federicorandazzo.com.ar/tone-generator/?share=<id>&name=<slug>`
- **Sheet de compartir** (`widgets/share_sheet.dart`) — genera el link con spinner y ofrece *Compartir en…* (share nativo / Web Share API) y *Copiar link*. Errores con reintento
- **Compartir lo actual** — si la sesión no está guardada se pide un nombre y se guarda; si tiene cambios sin guardar, se comparte tal como suena (avisado en el sheet)
- **ID por contenido** — SHA-256 (10 chars) de contenido + autor: compartir lo mismo dos veces reutiliza el link
- **Login anónimo** — Firebase Anonymous Auth, lazy, solo al compartir. Abrir un link no requiere usuario. La cuenta anónima puede promoverse con `linkWithCredential` conservando el `uid` (`ownerUid`), pensado para el futuro foro de la web
- **Importación idempotente** (`services/share_import_service.dart`) — ID local = UUID v5 de `shareId + idOriginal`: reabrir el link no duplica; si es una sesión propia se reutiliza; nombres repetidos reciben sufijo `(2)`
- **Datos de terceros validados** — `ToneSession.fromJson` / `ToneChannel.fromJson` limitan rangos (1–20.154 Hz, volumen 0–1, paneo ±1), máximo 16 canales y nombre de 80 caracteres
- **Flujo al abrir** — (disclaimer si es la primera vez) → *Abriendo sesión compartida…* → se agrega a la biblioteca → *¿Abrir ahora?* → protección de cambios → se carga **detenida**
- **Captura del link** — en `main.dart` antes de `runApp` (web: `?share=` + limpieza con `history.replaceState`; nativo: `app_links`). Con la app abierta: App Links (Android) y `launchQueue` (PWA de escritorio, `web/index.html`)
- **TTL 30 días** — `expiresAt` se renueva en cada apertura; limpieza lazy desde el cliente (plan Spark): hasta 10 vencidos al crear un link y cualquier vencido que se abra

#### Prioridad de apertura de un link
| Plataforma | Comportamiento |
|---|---|
| Android con app instalada | Abre la app (App Link verificado con `assetlinks.json`) |
| Android sin app, con PWA | Chrome abre la PWA instalada |
| Desktop con PWA instalada | La ventana abierta recibe el link (`launchQueue`) |
| Resto / iOS | Versión web |

#### Documento `tone_shared_links/{id}` (schema v1)
```
v: 1, type: "session", name, ownerUid,
summary: { channels, waveforms: [...] },
payload: "<JSON string { data: <sesión> }>",
createdAt, expiresAt
```

#### Reglas de seguridad (Firebase Console → Firestore → Reglas)
> Las reglas se editan a mano en Firebase Console; este bloque es la referencia. Va dentro de `match /databases/{database}/documents { … }`, junto al de `shared_links` del Metrónomo.

```
match /tone_shared_links/{linkId} {
  function isAdmin() {
    return request.auth != null
      && exists(/databases/$(database)/documents/usuarios/$(request.auth.uid))
      && get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data.rol == 'admin';
  }

  // Cualquiera puede abrir un link por ID (app, web, futuro foro)
  allow get: if true;

  // Solo admin, o la limpieza de links ya vencidos
  allow list: if isAdmin()
    || (resource.data.expiresAt < request.time && request.query.limit <= 20);

  allow create: if request.auth != null
    && request.resource.data.ownerUid == request.auth.uid
    && request.resource.data.type == 'session'
    && request.resource.data.payload is string
    && request.resource.data.payload.size() < 50000
    && request.resource.data.name is string
    && request.resource.data.name.size() <= 120
    && request.resource.data.expiresAt is timestamp
    && request.resource.data.keys().hasOnly(
         ['v', 'type', 'name', 'ownerUid', 'summary', 'payload', 'createdAt', 'expiresAt']);

  // Renovar TTL: solo `expiresAt`, con tope de ~31 días
  allow update: if isAdmin()
    || (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['expiresAt'])
        && request.resource.data.expiresAt is timestamp
        && request.resource.data.expiresAt < request.time + duration.value(31, 'd'));

  allow delete: if isAdmin()
    || (request.auth != null && resource.data.ownerUid == request.auth.uid)
    || resource.data.expiresAt < request.time;
}
```

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
│   ├── tone_session.dart              # ToneSession (sesión guardada/compartida)
│   └── permission_cache.dart          # Cache de permisos offline
├── providers/
│   ├── tone_generator_provider.dart   # Canales, playback, mixer, sesión activa, estado de trabajo
│   ├── session_provider.dart          # Biblioteca de sesiones (SharedPreferences)
│   └── settings_provider.dart         # UI scale, disclaimer
├── screens/
│   ├── tone_generator_screen.dart     # Pantalla principal + recepción de links
│   ├── library_screen.dart            # Biblioteca de sesiones
│   └── settings_screen.dart           # Ajustes
├── services/
│   ├── session_actions.dart           # Guardar / abrir / nueva / compartir (flujos de UI)
│   ├── deep_link_service.dart         # Links compartidos (Firestore + App Links)
│   ├── deep_link_web.dart             # JS interop (URL, launchQueue, Web Share)
│   ├── deep_link_stub.dart            # No-op fuera de la web
│   └── share_import_service.dart      # Importación idempotente
├── theme/
│   ├── app_colors.dart                # Paleta compartida
│   └── ui_scale.dart                  # Sistema de escalado dimensional
└── widgets/
    ├── channel_card.dart              # Card de canal (2 filas)
    ├── disclaimer_gate.dart           # Advertencia de seguridad
    ├── mini_knob.dart                 # Knob rotativo compacto
    ├── piano_keyboard.dart            # Teclado de piano global
    └── share_sheet.dart               # Sheet unificado de compartir

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
| `tone_shared_links/{id}` | ver *Compartir sesiones* | Links compartidos |

## Requisitos

- Flutter SDK >= 3.10.4
- Firebase project configurado con Auth (incluido **Anonymous**) + Firestore
- `lib/firebase_options.dart` y `android/app/google-services.json` no se versionan: copiarlos o regenerarlos con `flutterfire configure`
- Para Android: SHA-1 y SHA-256 registrados en Firebase

## Desarrollo

```bash
# Debug en Chrome
flutter run -d chrome

# Debug en Android
flutter run

# Tests
flutter test test/sharing_test.dart

# El motor nativo (C++/FFI) no requiere recompilación para cambios web
```

## Build web (deploy en federicorandazzo.com.ar/tone-generator/)

```bash
flutter build web --wasm --base-href /tone-generator/
# copiar build/web/* a mi-web-fede/public/tone-generator/ y correr deploy.ps1
```

App Links: `mi-web-fede/public/.well-known/assetlinks.json` incluye `com.saroo.tone_generator` con el SHA-256 de la clave de firma de Play.

## Seguridad Auditiva

> ⚠️ **Podés dañar tu audición o tus parlantes si reproducís tonos a volúmenes extremos.**
>
> Las personas no escuchan bien por debajo de 20 Hz ni por encima de 10.000 Hz. Si subís el volumen para compensar, podrías exponerte a niveles dañinos. Encontrá un nivel cómodo a 1.000 Hz y no lo superes demasiado.

## Licencia

Uso privado. Todos los derechos reservados.
