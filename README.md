# Tone Generator

Generador de frecuencias multi-canal con síntesis de ondas en tiempo real.

- **Repositorio:** https://github.com/randazzofederico-coder/ToneGenerator
- **Web:** https://federicorandazzo.com.ar/tone-generator/
- **Android:** `com.saroo.tone_generator` (Google Play)
- **Versión actual:** 1.2.0 (`1.2.0+5` en `pubspec.yaml`)

Aplicación profesional para generar tonos de prueba, calibrar equipos de audio, y explorar frecuencias. Soporta múltiples canales simultáneos con control independiente de frecuencia, volumen, paneo y forma de onda.

## Novedades 1.2.0

- **Cuenta del ecosistema (opcional)** — *Continuar con Google* en Ajustes; la misma cuenta del sitio y de las otras apps. Sin cuenta la app funciona igual
- **Sincronización local-first de la biblioteca** — `LibrarySync` de `fede_apps_core` contra `users/{uid}/appData/tonegenerator`: merge por ítem con `rev` y lápidas, copias *"… (otro dispositivo)"* en conflictos, purga de lápidas a los 30 días
- **Deshacer restaura el estado exacto** de la sesión (datos y fechas; misma posición en la lista)
- **Otras apps** — sugerencia ocasional de las otras apps y sección *Más apps* en Ajustes
- **Medición de uso local** (`UsageTracker`; la reproducción en segundo plano cuenta como uso)
- **Web en teléfonos siempre vertical** (`PortraitOnly`)
- **Snackbars legibles** (texto blanco sobre el fondo oscuro)
- **URL limpia** tras abrir un link compartido (sin `?share=`; un refresco no reimporta)
- **Eliminado el login heredado** (`AuthGate`): la app es libre

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
- **Cuenta** arriba de todo (`AccountSection` de `fede_apps_core`): *Continuar con Google*; con sesión, email, estado de la sincronización, *Sincronizar ahora* y *Cerrar sesión*
- **Idioma**: idioma del sistema (por defecto), Español o English
- **Tamaño de interfaz** configurable (70% – 130%)
- **Comunidad**: acceso al foro (https://federicorandazzo.com.ar/foro/)
- **Más apps** (`EcosystemSection` de `fede_apps_core`): links a las otras apps del ecosistema
- Advertencia de seguridad auditiva

### 🧩 Ecosistema (`fede_apps_core`)
- **Sugerencia de otras apps** — `EcosystemPrompts.maybeShowAppsPrompt` en momentos tranquilos (al entrar a Ajustes o al detener la reproducción a mano), con límites de frecuencia del paquete; nunca sobre la advertencia de seguridad
- **Medición de uso local** — `UsageTracker` (se inicializa en `main.dart`; la reproducción cuenta como actividad, también en segundo plano). Nunca bloquea el arranque
- **Web en teléfonos** — `PortraitOnly` en el `builder` del `MaterialApp`: la pantalla queda siempre vertical
- **Snackbars** — `snackBarTheme` con texto blanco (también para los avisos del paquete)

### 🌐 Idiomas
- Español e inglés con `flutter_localizations` + `intl` (gen-l10n). Textos en `lib/l10n/app_es.arb` (plantilla) y `app_en.arb`
- Por defecto sigue el idioma del sistema (cualquier `es_*` → español; el resto → inglés). Se puede forzar en Ajustes o desde la advertencia de seguridad inicial; se guarda en `SharedPreferences` (`settings_language`)
- En widgets: `context.l10n.clave`. Fuera de widgets (modelos, providers, servicios): `L10n.current.clave`, sincronizado desde el `builder` del `MaterialApp`
- `test/l10n_test.dart` verifica que ambos idiomas tengan las mismas claves y placeholders

### 🔐 Autenticación
- **App libre** — `main.dart` abre directo `DisclaimerGate(child: ToneGeneratorScreen())`. El login heredado (`AuthGate`: Google Sign-In, email/contraseña, permisos vía Firestore, cache offline, trial) fue eliminado; queda en el historial de git. Al iniciar, `SettingsProvider` borra las claves `perm_*` que pudiera haber dejado en `SharedPreferences`
- **Cuenta opcional (Google)** — `FedeAccount` de `fede_apps_core`, la misma cuenta del sitio y de las otras apps. Sin cuenta la app funciona igual. Android: `google_sign_in` vinculando la sesión anónima; web: popup
- **Login anónimo** al compartir sesiones, solo si no hay ningún usuario (`DeepLinkService._ensureUser`): nunca reemplaza ni cierra una sesión de Google; con cuenta, los links quedan a nombre de ese uid

### ☁️ Sincronización de la biblioteca
- Con sesión iniciada, la biblioteca se sincroniza con `users/{uid}/appData/tonegenerator` (colección `sessions`) mediante `LibrarySync` de `fede_apps_core` (merge por ítem, 1 lectura + como máximo 1 escritura por sync). Sin cuenta o sin internet no hace nada y nunca bloquea
- **Adapter:** `services/tone_sync_adapter.dart` (`ToneSyncAdapter`). `main.dart` crea `SessionProvider` y `ToneGeneratorProvider` antes de `runApp` (las mismas instancias que usa la UI) y llama a `LibrarySync.instance.configure(...)` después de `Firebase.initializeApp` y `UsageTracker.init`
- **Cambios locales:** todo lo que persiste la biblioteca (guardar, guardar como, renombrar, duplicar, eliminar, deshacer, importar un link) pasa por `SessionProvider._persist`, que llama a `LibrarySync.instance.notifyLocalChange()` (sync ~10 s después)
- **Cambios remotos:** `SessionProvider.applyRemote` escribe los ítems tal cual (sin subir `rev` ni tocar `updatedAt`) y no avisa al motor. Si la sesión **abierta** cambió en otro dispositivo: si se borró, se desvincula como en un borrado local (los canales quedan como sesión sin guardar); si se editó y no hay cambios sin guardar ni está sonando, se carga la versión nueva; si hay cambios sin guardar o está sonando, los canales no se tocan y la sesión queda marcada como modificada respecto de la versión nueva
- **Conflictos:** si la misma sesión se editó en dos dispositivos, gana la de `rev` más alta y la otra queda como copia *"… (otro dispositivo)"* / *"… (other device)"*
- **Purga de lápidas:** al cargar, solo si `LibrarySync.instance.canPurgeLocally(...)` (con cuenta: cuando ya se sincronizaron)
- **Sugerencia de login:** después de guardar una sesión **nueva** con 💾 o *Guardar como…* (con ≥ 3 sesiones, sin cuenta y con los límites de `PromptGate`; nunca sobre la advertencia de seguridad)
- **Requisitos:** Android: SHA-1/SHA-256 de las firmas en el proyecto Firebase y `google-services.json` actualizado; web: dominio autorizado en Firebase Auth
- Tests: `test/tone_sync_test.dart` (dos dispositivos con `InMemoryRemoteStore`)

### 📚 Biblioteca de sesiones
- **Sesión** = canales (frecuencia, onda, volumen, paneo, M/S/Ø) + Master Volume
- 💾 guarda sobre la sesión abierta (snackbar con *DESHACER*); si no existe pide un nombre. Al lado, **compartir** la sesión abierta. Menú ⋮: *Guardar como…*, *Nueva sesión*, *Biblioteca*, *Ajustes*
- **Tocar el nombre** de la sesión (barra superior) la renombra; si todavía no está guardada, pide un nombre y la guarda
- **Eliminar un canal** muestra *DESHACER* (vuelve a su posición; se ignora si mientras tanto se abrió otra sesión)
- **Snackbars** — todos pasan por `showAppSnack` (`services/session_actions.dart`): reemplazan al anterior y se ocultan solos (3 s, o 5 s con *DESHACER*). Desde Flutter 3.32 un SnackBar con acción queda fijo por defecto, por eso se fuerza `persist: false`
- **Cambios sin guardar** — el nombre en la barra superior se muestra en *cursiva* con `*`. Abrir otra sesión o crear una nueva ofrece *Guardar / Descartar / Cancelar*
- **Biblioteca** (`screens/library_screen.dart`) — búsqueda por nombre; tocar = abrir; menú ⋮: abrir, compartir, duplicar, renombrar, eliminar (confirmación + *DESHACER*). La sesión abierta se marca *Abierta*
- **Estado de trabajo persistente** — lo que está cargado se guarda solo (SharedPreferences, `tone_working_state`) y se restaura al reabrir la app
- **Nunca suena sola** — abrir una sesión (propia o recibida) detiene la reproducción; hay que dar Play
- **Modelo de datos (listo para sync)** — la biblioteca se guarda en SharedPreferences (`tone_sessions`, lista JSON de `ToneSession`). Además de sus datos, cada sesión lleva los campos del contrato `SyncFields` de `fede_apps_core`: `rev` (1 al crear/duplicar/importar; +1 en cada cambio: guardar, renombrar, eliminar, deshacer), `updatedAt`, `dev` (`DeviceIdentity.id`) y, al eliminar, `deleted`/`deletedAt`. **Eliminar deja una lápida** invisible para la app (lista, búsqueda, nombres repetidos, sesión abierta); las lápidas se purgan al cargar, a los 30 días. Guardar sobre una lápida (reabrir un link importado y luego borrado) la revive con un `rev` mayor. **Deshacer vuelve el tiempo atrás**: tanto *DESHACER* tras guardar como tras eliminar usan `SessionProvider.restoreSnapshot`, que restaura la sesión exactamente como estaba (datos, `createdAt` y `updatedAt`, así vuelve a su lugar en la lista); por dentro solo avanza `rev` (+1 sobre lo guardado, también sobre la lápida) y `dev`, para que un futuro sync lo vea como el cambio más nuevo. JSON viejo sin estas claves se lee como `rev: 1`. Los links compartidos no incluyen estos campos

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
- **Captura del link** — en `main.dart` antes de `runApp` (web: `?share=` + limpieza con `history.replaceState`, conservando el `state` de Flutter, y otra vez al terminar la importación — la URL queda en la de la app a secas; nativo: `app_links`). Con la app abierta: App Links (Android) y `launchQueue` (PWA de escritorio, `web/index.html`)
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
> Las reglas se editan a mano en Firebase Console; este bloque es la referencia (sección 5 de las reglas publicadas). Usa el helper `esAdmin()` definido al principio de `match /databases/{database}/documents { … }`.

```
match /tone_shared_links/{linkId} {
  // Cualquiera puede abrir un link por ID (app, web, futuro foro)
  allow get: if true;

  // Solo admin, o la limpieza de links ya vencidos
  allow list: if esAdmin()
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
  allow update: if esAdmin()
    || (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['expiresAt'])
        && request.resource.data.expiresAt is timestamp
        && request.resource.data.expiresAt < request.time + duration.value(31, 'd'));

  allow delete: if esAdmin()
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
├── firebase_options.dart              # Firebase config (no versionado)
├── l10n/
│   ├── app_es.arb / app_en.arb        # Textos (español = plantilla)
│   ├── app_localizations*.dart        # Generado por gen-l10n
│   └── l10n.dart                      # context.l10n, L10n.current, resolveAppLocale
├── models/
│   ├── channel_model.dart             # ToneChannel, Waveform, channelColor()
│   └── tone_session.dart              # ToneSession (sesión guardada/compartida)
├── providers/
│   ├── tone_generator_provider.dart   # Canales, playback, mixer, sesión activa, estado de trabajo
│   ├── session_provider.dart          # Biblioteca de sesiones (SharedPreferences)
│   └── settings_provider.dart         # UI scale, disclaimer, idioma
├── screens/
│   ├── tone_generator_screen.dart     # Pantalla principal + recepción de links
│   ├── library_screen.dart            # Biblioteca de sesiones
│   └── settings_screen.dart           # Ajustes
├── services/
│   ├── session_actions.dart           # Guardar / abrir / nueva / compartir (flujos de UI)
│   ├── deep_link_service.dart         # Links compartidos (Firestore + App Links)
│   ├── deep_link_web.dart             # JS interop (URL, launchQueue, Web Share)
│   ├── deep_link_stub.dart            # No-op fuera de la web
│   ├── share_import_service.dart      # Importación idempotente
│   └── tone_sync_adapter.dart         # Adapter de LibrarySync (cuenta + sync)
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
| `tone_shared_links/{id}` | ver *Compartir sesiones* | Links compartidos |
| `users/{uid}/appData/tonegenerator` | `sessions` (vía `LibrarySync`) | Biblioteca sincronizada (reglas en el sitio / `fede_apps_core`) |

## Requisitos

- Flutter SDK >= 3.10.4
- **`fede_apps_core`** (cuenta, sync, ecosistema, medición de uso, `PortraitOnly`) — dependencia por path `../fede_apps_core`: para compilar hay que clonar https://github.com/randazzofederico-coder/fede_apps_core **al lado** de este repo (`C:\dev\fede_apps_core`)
- Firebase project configurado con Auth (Google + **Anonymous**) + Firestore

### Configuración Firebase

- `lib/firebase_options.dart` y `android/app/google-services.json` **no se versionan** (`.gitignore`): copiarlos o regenerarlos con `flutterfire configure`
- **Android:** SHA-1 (y SHA-256) de las claves **debug**, **upload** y **Play App Signing** registradas en Firebase; tras agregar una, volver a bajar `google-services.json`

> [!IMPORTANT]
> La config **web** de `firebase_options.dart` usa el **mismo** `apiKey` / `appId` que el sitio (`AIzaSyB-J7F5pH90Zmk5VZ1jdsoPQvrNwPgy_f4` / `1:858245145787:web:9f041f6423348bca05b59e`): Firebase Auth guarda la sesión por `apiKey`, y así la sesión se comparte con federicorandazzo.com.ar y las otras apps web. Si se regenera con `flutterfire configure`, hay que volver a poner esos dos valores en `web`.

## Desarrollo

```bash
# Debug en Chrome
flutter run -d chrome

# Debug en Android
flutter run

# Tests
flutter test test/sharing_test.dart test/session_ui_test.dart test/session_sync_test.dart test/tone_sync_test.dart test/l10n_test.dart

# El motor nativo (C++/FFI) no requiere recompilación para cambios web
```

## Build y deploy web (federicorandazzo.com.ar/tone-generator/)

Lo hace el script del sitio: `mi-web-fede\deploy.ps1`, opción **4 - Tone Generator** (compila, copia `build\web` → `public\tone-generator\` con `robocopy /MIR`, compila Astro y sube). A mano, equivalente:

```bash
flutter build web --wasm --base-href /tone-generator/   # release por defecto
# copiar build/web/* a mi-web-fede/public/tone-generator/ y correr deploy.ps1
```

App Links: `mi-web-fede/public/.well-known/assetlinks.json` incluye `com.saroo.tone_generator` con el SHA-256 de la clave de firma de Play.

## Notas de mantenimiento

- **Origen del repo** — El proyecto nació como copia del Afinador. En noviembre 2026 se reinició el historial en este repo propio (commit inicial limpio); el `.git` anterior quedó respaldado localmente en `c:\dev\_backups\ToneGenerator-git-afinador`
- **Motor de audio** (`packages/native_audio_engine`) — Código compartido con Metrónomo/Afinador. No aplicar "arreglos automáticos" de warnings ahí sin revisar: quitar los valores por defecto de `_WebChannel` (`muted`, `solo`, `phaseInvert`) en `live_mixer_web.dart` rompe el build web
- **Problemas conocidos (no afectan la app)**
  - `packages/native_audio_engine/example` no encuentra `SoundTouchProcessor` (el ejemplo no se compila con la app)
  - `test/widget_test.dart` es la plantilla de Flutter (contador) y falla; los tests válidos son `sharing_test.dart`, `session_ui_test.dart`, `session_sync_test.dart`, `tone_sync_test.dart` y `l10n_test.dart`
- **Fin de línea** — `core.autocrlf=true`: los avisos *LF will be replaced by CRLF* de git son normales
- **Tests de widgets** — Crear `SessionProvider` dentro del cuerpo de cada `testWidgets` (no en `setUp`): su `Completer` creado fuera del *fake async* nunca resuelve. El `MaterialApp` de prueba necesita `localizationsDelegates` (los flujos usan `context.l10n`); los tests que verifican textos fijan `locale: Locale('es')` / `L10n.current` en español
- **Textos nuevos** — Agregar la clave en `app_es.arb` y `app_en.arb` y correr `flutter gen-l10n` (también se regenera con `flutter pub get` / `flutter run`). No hardcodear strings visibles en la UI
- **Antes de commitear** — `flutter analyze lib` sin errores y `flutter test test/sharing_test.dart test/session_ui_test.dart test/session_sync_test.dart test/tone_sync_test.dart test/l10n_test.dart` en verde

## Historial de cambios

| Fecha | Cambio |
|---|---|
| 2026-11-01 | Repo propio, commit inicial limpio |
| 2026-11-01 | Biblioteca de sesiones, estado de trabajo persistente y compartir sesiones por link (`tone_shared_links`, login anónimo, importación idempotente) |
| 2026-11-01 | App Links Android, PWA (`launch_handler`, `launchQueue`) y meta tags para previews |
| 2026-11-01 | Renombrar tocando el nombre, compartir junto a guardar, DESHACER al borrar canal, snackbars que se ocultan solos |
| 2026-11-01 | Limpieza de warnings (`withValues`, imports sin uso, formato) |
| 2026-11-01 | Idioma inglés (gen-l10n), selector de idioma arriba de todo en Ajustes y acceso al foro |
| 2026-11-02 | **1.1.0** (`+4`) — Eliminado el login heredado (`AuthGate`): app libre |
| 2026-11-02 | Integración de `fede_apps_core` (medición de uso, sugerencia de otras apps, *Más apps*) |
| 2026-11-02 | Biblioteca lista para sync (`rev`, lápidas, purga a 30 días); deshacer restaura el estado exacto |
| 2026-11-02 | Cuenta del ecosistema (Google) y sincronización de la biblioteca (`LibrarySync`) |
| 2026-11-06 | Snackbars legibles, `PortraitOnly` en la web de teléfonos, URL limpia tras abrir un link compartido |
| 2026-11-06 | **1.2.0** (`+5`) — publicada en producción |

## Seguridad Auditiva

> ⚠️ **Podés dañar tu audición o tus parlantes si reproducís tonos a volúmenes extremos.**
>
> Las personas no escuchan bien por debajo de 20 Hz ni por encima de 10.000 Hz. Si subís el volumen para compensar, podrías exponerte a niveles dañinos. Encontrá un nivel cómodo a 1.000 Hz y no lo superes demasiado.

## Licencia

Uso privado. Todos los derechos reservados.
