import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Tone Generator'**
  String get appTitle;

  /// No description provided for @languageSystem.
  ///
  /// In es, this message translates to:
  /// **'Idioma del sistema'**
  String get languageSystem;

  /// No description provided for @languageSpanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageEnglish.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @actionCancel.
  ///
  /// In es, this message translates to:
  /// **'CANCELAR'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In es, this message translates to:
  /// **'GUARDAR'**
  String get actionSave;

  /// No description provided for @actionSaveOnly.
  ///
  /// In es, this message translates to:
  /// **'SOLO GUARDAR'**
  String get actionSaveOnly;

  /// No description provided for @actionOpen.
  ///
  /// In es, this message translates to:
  /// **'ABRIR'**
  String get actionOpen;

  /// No description provided for @actionRename.
  ///
  /// In es, this message translates to:
  /// **'RENOMBRAR'**
  String get actionRename;

  /// No description provided for @actionDelete.
  ///
  /// In es, this message translates to:
  /// **'ELIMINAR'**
  String get actionDelete;

  /// No description provided for @actionDiscard.
  ///
  /// In es, this message translates to:
  /// **'DESCARTAR'**
  String get actionDiscard;

  /// No description provided for @actionUndo.
  ///
  /// In es, this message translates to:
  /// **'DESHACER'**
  String get actionUndo;

  /// No description provided for @actionRetry.
  ///
  /// In es, this message translates to:
  /// **'REINTENTAR'**
  String get actionRetry;

  /// No description provided for @dialogCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get dialogCancel;

  /// No description provided for @dialogOk.
  ///
  /// In es, this message translates to:
  /// **'OK'**
  String get dialogOk;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Idioma de la interfaz'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsInterfaceSection.
  ///
  /// In es, this message translates to:
  /// **'Interfaz'**
  String get settingsInterfaceSection;

  /// No description provided for @settingsUiScaleTitle.
  ///
  /// In es, this message translates to:
  /// **'Tamaño de interfaz'**
  String get settingsUiScaleTitle;

  /// No description provided for @scaleCompact.
  ///
  /// In es, this message translates to:
  /// **'Compacto'**
  String get scaleCompact;

  /// No description provided for @scaleSmall.
  ///
  /// In es, this message translates to:
  /// **'Pequeño'**
  String get scaleSmall;

  /// No description provided for @scaleNormal.
  ///
  /// In es, this message translates to:
  /// **'Normal'**
  String get scaleNormal;

  /// No description provided for @scaleLarge.
  ///
  /// In es, this message translates to:
  /// **'Grande'**
  String get scaleLarge;

  /// No description provided for @scaleExtraLarge.
  ///
  /// In es, this message translates to:
  /// **'Extra grande'**
  String get scaleExtraLarge;

  /// No description provided for @settingsForumTitle.
  ///
  /// In es, this message translates to:
  /// **'Comunidad'**
  String get settingsForumTitle;

  /// No description provided for @settingsForumSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Consultas, sugerencias y novedades en el foro'**
  String get settingsForumSubtitle;

  /// No description provided for @settingsForumButton.
  ///
  /// In es, this message translates to:
  /// **'Ir al Foro'**
  String get settingsForumButton;

  /// No description provided for @settingsMoreAppsTitle.
  ///
  /// In es, this message translates to:
  /// **'Más apps'**
  String get settingsMoreAppsTitle;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutDescription.
  ///
  /// In es, this message translates to:
  /// **'Generador de frecuencias multi-canal\ncon síntesis de ondas en tiempo real.'**
  String get settingsAboutDescription;

  /// No description provided for @settingsAboutVisitWebsite.
  ///
  /// In es, this message translates to:
  /// **'Visitar federicorandazzo.com.ar/apps/'**
  String get settingsAboutVisitWebsite;

  /// No description provided for @settingsShowSafetyWarning.
  ///
  /// In es, this message translates to:
  /// **'Ver advertencia de seguridad'**
  String get settingsShowSafetyWarning;

  /// No description provided for @warningTitle.
  ///
  /// In es, this message translates to:
  /// **'Advertencia'**
  String get warningTitle;

  /// No description provided for @warningShortBody.
  ///
  /// In es, this message translates to:
  /// **'Podés dañar tu audición o tus parlantes si reproducís tonos a volúmenes extremos.\n\nEncontrá un nivel cómodo a 1.000 Hz y no lo superes demasiado, especialmente en frecuencias agudas.'**
  String get warningShortBody;

  /// No description provided for @warningGotIt.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get warningGotIt;

  /// No description provided for @disclaimerTitle.
  ///
  /// In es, this message translates to:
  /// **'Advertencia de Seguridad'**
  String get disclaimerTitle;

  /// No description provided for @disclaimerParagraph1.
  ///
  /// In es, this message translates to:
  /// **'⚠️  Podés dañar tu audición o tus parlantes si reproducís tonos a volúmenes extremos.'**
  String get disclaimerParagraph1;

  /// No description provided for @disclaimerParagraph2.
  ///
  /// In es, this message translates to:
  /// **'Las personas no escuchan bien los sonidos por debajo de 20 Hz ni por encima de 10.000 Hz. Si subís el volumen del dispositivo para compensar, podrías exponerte a niveles de sonido dañinos y someter a tus parlantes a corrientes perjudiciales.'**
  String get disclaimerParagraph2;

  /// No description provided for @disclaimerParagraph3.
  ///
  /// In es, this message translates to:
  /// **'Para ser prudente, encontrá el nivel de volumen que te permita escuchar un tono de 1.000 Hz sin molestias y no te alejes mucho de ese nivel, aunque no escuches mucho — especialmente en el rango agudo, donde tu audición es más frágil.'**
  String get disclaimerParagraph3;

  /// No description provided for @disclaimerAccept.
  ///
  /// In es, this message translates to:
  /// **'Entiendo y acepto'**
  String get disclaimerAccept;

  /// No description provided for @tooltipSaveSession.
  ///
  /// In es, this message translates to:
  /// **'Guardar sesión'**
  String get tooltipSaveSession;

  /// No description provided for @tooltipMoreOptions.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get tooltipMoreOptions;

  /// No description provided for @menuSaveAs.
  ///
  /// In es, this message translates to:
  /// **'Guardar como…'**
  String get menuSaveAs;

  /// No description provided for @menuNewSession.
  ///
  /// In es, this message translates to:
  /// **'Nueva sesión'**
  String get menuNewSession;

  /// No description provided for @emptyChannelsHint.
  ///
  /// In es, this message translates to:
  /// **'Agregá un canal para comenzar'**
  String get emptyChannelsHint;

  /// No description provided for @addChannel.
  ///
  /// In es, this message translates to:
  /// **'Agregar Canal'**
  String get addChannel;

  /// No description provided for @masterVolume.
  ///
  /// In es, this message translates to:
  /// **'Volumen maestro'**
  String get masterVolume;

  /// No description provided for @untitledSession.
  ///
  /// In es, this message translates to:
  /// **'Sin título'**
  String get untitledSession;

  /// No description provided for @shareOpening.
  ///
  /// In es, this message translates to:
  /// **'Abriendo sesión compartida…'**
  String get shareOpening;

  /// No description provided for @shareInvalidLink.
  ///
  /// In es, this message translates to:
  /// **'El link compartido no es válido o expiró.'**
  String get shareInvalidLink;

  /// No description provided for @shareImportFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar la sesión compartida.'**
  String get shareImportFailed;

  /// No description provided for @shareSessionLoaded.
  ///
  /// In es, this message translates to:
  /// **'Sesión «{name}» cargada. Revisá el volumen y dale Play.'**
  String shareSessionLoaded(String name);

  /// No description provided for @shareAlreadyInLibrary.
  ///
  /// In es, this message translates to:
  /// **'Ya estaba en tu biblioteca.'**
  String get shareAlreadyInLibrary;

  /// No description provided for @shareAddedToLibrary.
  ///
  /// In es, this message translates to:
  /// **'Se agregó a tu biblioteca ({summary}).'**
  String shareAddedToLibrary(String summary);

  /// No description provided for @shareReceivedTitle.
  ///
  /// In es, this message translates to:
  /// **'Sesión recibida'**
  String get shareReceivedTitle;

  /// No description provided for @shareReceivedBody.
  ///
  /// In es, this message translates to:
  /// **'«{name}»\n{status}\n\n¿Querés abrirla ahora?'**
  String shareReceivedBody(String name, String status);

  /// No description provided for @libraryTitle.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca'**
  String get libraryTitle;

  /// No description provided for @librarySearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar sesión'**
  String get librarySearchHint;

  /// No description provided for @libraryNoResults.
  ///
  /// In es, this message translates to:
  /// **'No hay sesiones con ese nombre'**
  String get libraryNoResults;

  /// No description provided for @libraryEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no guardaste sesiones.\nUsá 💾 en la pantalla principal para guardar la actual.'**
  String get libraryEmpty;

  /// No description provided for @libraryOpenBadge.
  ///
  /// In es, this message translates to:
  /// **'Abierta'**
  String get libraryOpenBadge;

  /// No description provided for @tooltipOptions.
  ///
  /// In es, this message translates to:
  /// **'Opciones'**
  String get tooltipOptions;

  /// No description provided for @menuOpen.
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get menuOpen;

  /// No description provided for @menuShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get menuShare;

  /// No description provided for @menuDuplicate.
  ///
  /// In es, this message translates to:
  /// **'Duplicar'**
  String get menuDuplicate;

  /// No description provided for @menuRename.
  ///
  /// In es, this message translates to:
  /// **'Renombrar'**
  String get menuRename;

  /// No description provided for @menuDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get menuDelete;

  /// No description provided for @libraryNoChannels.
  ///
  /// In es, this message translates to:
  /// **'Sin canales'**
  String get libraryNoChannels;

  /// No description provided for @sessionNoChannelsToShare.
  ///
  /// In es, this message translates to:
  /// **'La sesión no tiene canales para compartir.'**
  String get sessionNoChannelsToShare;

  /// No description provided for @sessionDuplicated.
  ///
  /// In es, this message translates to:
  /// **'Se creó «{name}»'**
  String sessionDuplicated(String name);

  /// No description provided for @deleteSessionTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar sesión'**
  String get deleteSessionTitle;

  /// No description provided for @deleteSessionConfirm.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar «{name}» de la biblioteca?'**
  String deleteSessionConfirm(String name);

  /// No description provided for @sessionDeleted.
  ///
  /// In es, this message translates to:
  /// **'Sesión «{name}» eliminada'**
  String sessionDeleted(String name);

  /// No description provided for @renameSessionTitle.
  ///
  /// In es, this message translates to:
  /// **'Renombrar sesión'**
  String get renameSessionTitle;

  /// No description provided for @saveSessionAsTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar sesión como…'**
  String get saveSessionAsTitle;

  /// No description provided for @sessionNameHint.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la sesión'**
  String get sessionNameHint;

  /// No description provided for @sessionNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribí un nombre'**
  String get sessionNameRequired;

  /// No description provided for @sessionNameExists.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una sesión con ese nombre'**
  String get sessionNameExists;

  /// No description provided for @sessionSaved.
  ///
  /// In es, this message translates to:
  /// **'Sesión «{name}» guardada'**
  String sessionSaved(String name);

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In es, this message translates to:
  /// **'Cambios sin guardar'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesNew.
  ///
  /// In es, this message translates to:
  /// **'La sesión actual no está guardada. ¿Qué querés hacer antes de continuar?'**
  String get unsavedChangesNew;

  /// No description provided for @unsavedChangesNamed.
  ///
  /// In es, this message translates to:
  /// **'La sesión «{name}» tiene cambios sin guardar. ¿Qué querés hacer antes de continuar?'**
  String unsavedChangesNamed(String name);

  /// No description provided for @channelDeleted.
  ///
  /// In es, this message translates to:
  /// **'Canal eliminado'**
  String get channelDeleted;

  /// No description provided for @shareSessionTitle.
  ///
  /// In es, this message translates to:
  /// **'Compartir sesión'**
  String get shareSessionTitle;

  /// No description provided for @shareAddChannelFirst.
  ///
  /// In es, this message translates to:
  /// **'Agregá al menos un canal para compartir.'**
  String get shareAddChannelFirst;

  /// No description provided for @shareIncludesUnsaved.
  ///
  /// In es, this message translates to:
  /// **'Incluye los cambios sin guardar.'**
  String get shareIncludesUnsaved;

  /// No description provided for @shareNativeFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el menú de compartir. Copiamos el link.'**
  String get shareNativeFailed;

  /// No description provided for @shareGeneratingLink.
  ///
  /// In es, this message translates to:
  /// **'Generando link…'**
  String get shareGeneratingLink;

  /// No description provided for @shareLinkFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear el link.'**
  String get shareLinkFailed;

  /// No description provided for @shareVia.
  ///
  /// In es, this message translates to:
  /// **'COMPARTIR EN…'**
  String get shareVia;

  /// No description provided for @shareLinkCopied.
  ///
  /// In es, this message translates to:
  /// **'¡LINK COPIADO!'**
  String get shareLinkCopied;

  /// No description provided for @shareCopyLink.
  ///
  /// In es, this message translates to:
  /// **'COPIAR LINK'**
  String get shareCopyLink;

  /// No description provided for @shareErrorServer.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con el servidor para crear el link.'**
  String get shareErrorServer;

  /// No description provided for @shareErrorPermission.
  ///
  /// In es, this message translates to:
  /// **'El servidor rechazó el link (permisos).'**
  String get shareErrorPermission;

  /// No description provided for @shareErrorConnection.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear el link. Revisá tu conexión.'**
  String get shareErrorConnection;

  /// No description provided for @shareLinkTitle.
  ///
  /// In es, this message translates to:
  /// **'Sesión: {name}'**
  String shareLinkTitle(String name);

  /// No description provided for @shareLinkMessage.
  ///
  /// In es, this message translates to:
  /// **'🎛️ Te comparto la sesión «{name}» ({summary}) en Tone Generator:\n{url}'**
  String shareLinkMessage(String name, String summary, String url);

  /// Short session summary, e.g. "3 canales".
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 canal} other{{count} canales}}'**
  String channelCount(int count);

  /// No description provided for @sessionDefaultName.
  ///
  /// In es, this message translates to:
  /// **'Sesión'**
  String get sessionDefaultName;

  /// No description provided for @sessionCopyName.
  ///
  /// In es, this message translates to:
  /// **'{name} (copia)'**
  String sessionCopyName(String name);

  /// Copia creada cuando la misma sesión se editó en dos dispositivos.
  ///
  /// In es, this message translates to:
  /// **'{name} (otro dispositivo)'**
  String sessionConflictCopyName(String name);

  /// No description provided for @settingsAccountTitle.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get settingsAccountTitle;

  /// No description provided for @waveSine.
  ///
  /// In es, this message translates to:
  /// **'Senoidal'**
  String get waveSine;

  /// No description provided for @waveSquare.
  ///
  /// In es, this message translates to:
  /// **'Cuadrada'**
  String get waveSquare;

  /// No description provided for @waveTriangle.
  ///
  /// In es, this message translates to:
  /// **'Triangular'**
  String get waveTriangle;

  /// No description provided for @waveSawtooth.
  ///
  /// In es, this message translates to:
  /// **'Sierra'**
  String get waveSawtooth;

  /// No description provided for @frequencyDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Frecuencia (Hz)'**
  String get frequencyDialogTitle;

  /// No description provided for @pianoChannelLabel.
  ///
  /// In es, this message translates to:
  /// **'Canal:'**
  String get pianoChannelLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
