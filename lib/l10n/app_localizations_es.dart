// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Tone Generator';

  @override
  String get languageSystem => 'Idioma del sistema';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String get actionCancel => 'CANCELAR';

  @override
  String get actionSave => 'GUARDAR';

  @override
  String get actionSaveOnly => 'SOLO GUARDAR';

  @override
  String get actionOpen => 'ABRIR';

  @override
  String get actionRename => 'RENOMBRAR';

  @override
  String get actionDelete => 'ELIMINAR';

  @override
  String get actionDiscard => 'DESCARTAR';

  @override
  String get actionUndo => 'DESHACER';

  @override
  String get actionRetry => 'REINTENTAR';

  @override
  String get dialogCancel => 'Cancelar';

  @override
  String get dialogOk => 'OK';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsLanguageTitle => 'Idioma';

  @override
  String get settingsLanguageSubtitle => 'Idioma de la interfaz';

  @override
  String get settingsInterfaceSection => 'Interfaz';

  @override
  String get settingsUiScaleTitle => 'Tamaño de interfaz';

  @override
  String get scaleCompact => 'Compacto';

  @override
  String get scaleSmall => 'Pequeño';

  @override
  String get scaleNormal => 'Normal';

  @override
  String get scaleLarge => 'Grande';

  @override
  String get scaleExtraLarge => 'Extra grande';

  @override
  String get settingsForumTitle => 'Comunidad';

  @override
  String get settingsForumSubtitle =>
      'Consultas, sugerencias y novedades en el foro';

  @override
  String get settingsForumButton => 'Ir al Foro';

  @override
  String get settingsMoreAppsTitle => 'Más apps';

  @override
  String get settingsAboutTitle => 'Acerca de';

  @override
  String get settingsAboutDescription =>
      'Generador de frecuencias multi-canal\ncon síntesis de ondas en tiempo real.';

  @override
  String get settingsAboutVisitWebsite =>
      'Visitar federicorandazzo.com.ar/apps/';

  @override
  String get settingsShowSafetyWarning => 'Ver advertencia de seguridad';

  @override
  String get warningTitle => 'Advertencia';

  @override
  String get warningShortBody =>
      'Podés dañar tu audición o tus parlantes si reproducís tonos a volúmenes extremos.\n\nEncontrá un nivel cómodo a 1.000 Hz y no lo superes demasiado, especialmente en frecuencias agudas.';

  @override
  String get warningGotIt => 'Entendido';

  @override
  String get disclaimerTitle => 'Advertencia de Seguridad';

  @override
  String get disclaimerParagraph1 =>
      '⚠️  Podés dañar tu audición o tus parlantes si reproducís tonos a volúmenes extremos.';

  @override
  String get disclaimerParagraph2 =>
      'Las personas no escuchan bien los sonidos por debajo de 20 Hz ni por encima de 10.000 Hz. Si subís el volumen del dispositivo para compensar, podrías exponerte a niveles de sonido dañinos y someter a tus parlantes a corrientes perjudiciales.';

  @override
  String get disclaimerParagraph3 =>
      'Para ser prudente, encontrá el nivel de volumen que te permita escuchar un tono de 1.000 Hz sin molestias y no te alejes mucho de ese nivel, aunque no escuches mucho — especialmente en el rango agudo, donde tu audición es más frágil.';

  @override
  String get disclaimerAccept => 'Entiendo y acepto';

  @override
  String get tooltipSaveSession => 'Guardar sesión';

  @override
  String get tooltipMoreOptions => 'Más opciones';

  @override
  String get menuSaveAs => 'Guardar como…';

  @override
  String get menuNewSession => 'Nueva sesión';

  @override
  String get emptyChannelsHint => 'Agregá un canal para comenzar';

  @override
  String get addChannel => 'Agregar Canal';

  @override
  String get masterVolume => 'Volumen maestro';

  @override
  String get untitledSession => 'Sin título';

  @override
  String get shareOpening => 'Abriendo sesión compartida…';

  @override
  String get shareInvalidLink => 'El link compartido no es válido o expiró.';

  @override
  String get shareImportFailed => 'No se pudo importar la sesión compartida.';

  @override
  String shareSessionLoaded(String name) {
    return 'Sesión «$name» cargada. Revisá el volumen y dale Play.';
  }

  @override
  String get shareAlreadyInLibrary => 'Ya estaba en tu biblioteca.';

  @override
  String shareAddedToLibrary(String summary) {
    return 'Se agregó a tu biblioteca ($summary).';
  }

  @override
  String get shareReceivedTitle => 'Sesión recibida';

  @override
  String shareReceivedBody(String name, String status) {
    return '«$name»\n$status\n\n¿Querés abrirla ahora?';
  }

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String get librarySearchHint => 'Buscar sesión';

  @override
  String get libraryNoResults => 'No hay sesiones con ese nombre';

  @override
  String get libraryEmpty =>
      'Todavía no guardaste sesiones.\nUsá 💾 en la pantalla principal para guardar la actual.';

  @override
  String get libraryOpenBadge => 'Abierta';

  @override
  String get tooltipOptions => 'Opciones';

  @override
  String get menuOpen => 'Abrir';

  @override
  String get menuShare => 'Compartir';

  @override
  String get menuDuplicate => 'Duplicar';

  @override
  String get menuRename => 'Renombrar';

  @override
  String get menuDelete => 'Eliminar';

  @override
  String get libraryNoChannels => 'Sin canales';

  @override
  String get sessionNoChannelsToShare =>
      'La sesión no tiene canales para compartir.';

  @override
  String sessionDuplicated(String name) {
    return 'Se creó «$name»';
  }

  @override
  String get deleteSessionTitle => 'Eliminar sesión';

  @override
  String deleteSessionConfirm(String name) {
    return '¿Eliminar «$name» de la biblioteca?';
  }

  @override
  String sessionDeleted(String name) {
    return 'Sesión «$name» eliminada';
  }

  @override
  String get renameSessionTitle => 'Renombrar sesión';

  @override
  String get saveSessionAsTitle => 'Guardar sesión como…';

  @override
  String get sessionNameHint => 'Nombre de la sesión';

  @override
  String get sessionNameRequired => 'Escribí un nombre';

  @override
  String get sessionNameExists => 'Ya existe una sesión con ese nombre';

  @override
  String sessionSaved(String name) {
    return 'Sesión «$name» guardada';
  }

  @override
  String get unsavedChangesTitle => 'Cambios sin guardar';

  @override
  String get unsavedChangesNew =>
      'La sesión actual no está guardada. ¿Qué querés hacer antes de continuar?';

  @override
  String unsavedChangesNamed(String name) {
    return 'La sesión «$name» tiene cambios sin guardar. ¿Qué querés hacer antes de continuar?';
  }

  @override
  String get channelDeleted => 'Canal eliminado';

  @override
  String get shareSessionTitle => 'Compartir sesión';

  @override
  String get shareAddChannelFirst => 'Agregá al menos un canal para compartir.';

  @override
  String get shareIncludesUnsaved => 'Incluye los cambios sin guardar.';

  @override
  String get shareNativeFailed =>
      'No se pudo abrir el menú de compartir. Copiamos el link.';

  @override
  String get shareGeneratingLink => 'Generando link…';

  @override
  String get shareLinkFailed => 'No se pudo crear el link.';

  @override
  String get shareVia => 'COMPARTIR EN…';

  @override
  String get shareLinkCopied => '¡LINK COPIADO!';

  @override
  String get shareCopyLink => 'COPIAR LINK';

  @override
  String get shareErrorServer =>
      'No se pudo conectar con el servidor para crear el link.';

  @override
  String get shareErrorPermission => 'El servidor rechazó el link (permisos).';

  @override
  String get shareErrorConnection =>
      'No se pudo crear el link. Revisá tu conexión.';

  @override
  String shareLinkTitle(String name) {
    return 'Sesión: $name';
  }

  @override
  String shareLinkMessage(String name, String summary, String url) {
    return '🎛️ Te comparto la sesión «$name» ($summary) en Tone Generator:\n$url';
  }

  @override
  String channelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canales',
      one: '1 canal',
    );
    return '$_temp0';
  }

  @override
  String get sessionDefaultName => 'Sesión';

  @override
  String sessionCopyName(String name) {
    return '$name (copia)';
  }

  @override
  String sessionConflictCopyName(String name) {
    return '$name (otro dispositivo)';
  }

  @override
  String get settingsAccountTitle => 'Cuenta';

  @override
  String get waveSine => 'Senoidal';

  @override
  String get waveSquare => 'Cuadrada';

  @override
  String get waveTriangle => 'Triangular';

  @override
  String get waveSawtooth => 'Sierra';

  @override
  String get frequencyDialogTitle => 'Frecuencia (Hz)';

  @override
  String get pianoChannelLabel => 'Canal:';
}
