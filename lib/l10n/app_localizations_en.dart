// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tone Generator';

  @override
  String get languageSystem => 'System language';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageEnglish => 'English';

  @override
  String get actionCancel => 'CANCEL';

  @override
  String get actionSave => 'SAVE';

  @override
  String get actionSaveOnly => 'SAVE ONLY';

  @override
  String get actionOpen => 'OPEN';

  @override
  String get actionRename => 'RENAME';

  @override
  String get actionDelete => 'DELETE';

  @override
  String get actionDiscard => 'DISCARD';

  @override
  String get actionUndo => 'UNDO';

  @override
  String get actionRetry => 'RETRY';

  @override
  String get dialogCancel => 'Cancel';

  @override
  String get dialogOk => 'OK';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Interface language';

  @override
  String get settingsInterfaceSection => 'Interface';

  @override
  String get settingsUiScaleTitle => 'Interface size';

  @override
  String get scaleCompact => 'Compact';

  @override
  String get scaleSmall => 'Small';

  @override
  String get scaleNormal => 'Normal';

  @override
  String get scaleLarge => 'Large';

  @override
  String get scaleExtraLarge => 'Extra large';

  @override
  String get settingsForumTitle => 'Community';

  @override
  String get settingsForumSubtitle =>
      'Questions, suggestions and news in the forum';

  @override
  String get settingsForumButton => 'Go to Forum';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get settingsAboutDescription =>
      'Multi-channel frequency generator\nwith real-time waveform synthesis.';

  @override
  String get settingsAboutVisitWebsite => 'Visit federicorandazzo.com.ar/apps/';

  @override
  String get settingsShowSafetyWarning => 'View safety warning';

  @override
  String get warningTitle => 'Warning';

  @override
  String get warningShortBody =>
      'You can damage your hearing or your speakers if you play tones at extreme volumes.\n\nFind a comfortable level at 1,000 Hz and don\'t go much above it, especially at high frequencies.';

  @override
  String get warningGotIt => 'Got it';

  @override
  String get disclaimerTitle => 'Safety Warning';

  @override
  String get disclaimerParagraph1 =>
      '⚠️  You can damage your hearing or your speakers if you play tones at extreme volumes.';

  @override
  String get disclaimerParagraph2 =>
      'People can\'t hear sounds below 20 Hz or above 10,000 Hz very well. If you turn up the volume on your device to compensate, you could expose yourself to harmful sound levels and your speakers to harmful currents.';

  @override
  String get disclaimerParagraph3 =>
      'To be safe, note the volume level that allows you to listen to a 1,000 Hz tone without discomfort and do not stray too far above this level, even if you can\'t hear much — especially in the high range, where your hearing is the most fragile.';

  @override
  String get disclaimerAccept => 'I understand and accept';

  @override
  String get tooltipSaveSession => 'Save session';

  @override
  String get tooltipMoreOptions => 'More options';

  @override
  String get menuSaveAs => 'Save as…';

  @override
  String get menuNewSession => 'New session';

  @override
  String get emptyChannelsHint => 'Add a channel to get started';

  @override
  String get addChannel => 'Add Channel';

  @override
  String get masterVolume => 'Master Volume';

  @override
  String get untitledSession => 'Untitled';

  @override
  String get shareOpening => 'Opening shared session…';

  @override
  String get shareInvalidLink => 'The shared link is invalid or has expired.';

  @override
  String get shareImportFailed => 'Couldn\'t import the shared session.';

  @override
  String shareSessionLoaded(String name) {
    return 'Session “$name” loaded. Check the volume and press Play.';
  }

  @override
  String get shareAlreadyInLibrary => 'It was already in your library.';

  @override
  String shareAddedToLibrary(String summary) {
    return 'Added to your library ($summary).';
  }

  @override
  String get shareReceivedTitle => 'Session received';

  @override
  String shareReceivedBody(String name, String status) {
    return '“$name”\n$status\n\nOpen it now?';
  }

  @override
  String get libraryTitle => 'Library';

  @override
  String get librarySearchHint => 'Search session';

  @override
  String get libraryNoResults => 'No sessions with that name';

  @override
  String get libraryEmpty =>
      'You haven\'t saved any sessions yet.\nUse 💾 on the main screen to save the current one.';

  @override
  String get libraryOpenBadge => 'Open';

  @override
  String get tooltipOptions => 'Options';

  @override
  String get menuOpen => 'Open';

  @override
  String get menuShare => 'Share';

  @override
  String get menuDuplicate => 'Duplicate';

  @override
  String get menuRename => 'Rename';

  @override
  String get menuDelete => 'Delete';

  @override
  String get libraryNoChannels => 'No channels';

  @override
  String get sessionNoChannelsToShare =>
      'This session has no channels to share.';

  @override
  String sessionDuplicated(String name) {
    return 'Created “$name”';
  }

  @override
  String get deleteSessionTitle => 'Delete session';

  @override
  String deleteSessionConfirm(String name) {
    return 'Delete “$name” from the library?';
  }

  @override
  String sessionDeleted(String name) {
    return 'Session “$name” deleted';
  }

  @override
  String get renameSessionTitle => 'Rename session';

  @override
  String get saveSessionAsTitle => 'Save session as…';

  @override
  String get sessionNameHint => 'Session name';

  @override
  String get sessionNameRequired => 'Enter a name';

  @override
  String get sessionNameExists => 'A session with that name already exists';

  @override
  String sessionSaved(String name) {
    return 'Session “$name” saved';
  }

  @override
  String get unsavedChangesTitle => 'Unsaved changes';

  @override
  String get unsavedChangesNew =>
      'The current session is not saved. What do you want to do before continuing?';

  @override
  String unsavedChangesNamed(String name) {
    return 'The session “$name” has unsaved changes. What do you want to do before continuing?';
  }

  @override
  String get channelDeleted => 'Channel deleted';

  @override
  String get shareSessionTitle => 'Share session';

  @override
  String get shareAddChannelFirst => 'Add at least one channel to share.';

  @override
  String get shareIncludesUnsaved => 'Includes unsaved changes.';

  @override
  String get shareNativeFailed =>
      'Couldn\'t open the share menu. The link was copied instead.';

  @override
  String get shareGeneratingLink => 'Generating link…';

  @override
  String get shareLinkFailed => 'Couldn\'t create the link.';

  @override
  String get shareVia => 'SHARE VIA…';

  @override
  String get shareLinkCopied => 'LINK COPIED!';

  @override
  String get shareCopyLink => 'COPY LINK';

  @override
  String get shareErrorServer =>
      'Couldn\'t connect to the server to create the link.';

  @override
  String get shareErrorPermission =>
      'The server rejected the link (permissions).';

  @override
  String get shareErrorConnection =>
      'Couldn\'t create the link. Check your connection.';

  @override
  String shareLinkTitle(String name) {
    return 'Session: $name';
  }

  @override
  String shareLinkMessage(String name, String summary, String url) {
    return '🎛️ Here\'s my session “$name” ($summary) on Tone Generator:\n$url';
  }

  @override
  String channelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels',
      one: '1 channel',
    );
    return '$_temp0';
  }

  @override
  String get sessionDefaultName => 'Session';

  @override
  String sessionCopyName(String name) {
    return '$name (copy)';
  }

  @override
  String get waveSine => 'Sine';

  @override
  String get waveSquare => 'Square';

  @override
  String get waveTriangle => 'Triangle';

  @override
  String get waveSawtooth => 'Sawtooth';

  @override
  String get frequencyDialogTitle => 'Frequency (Hz)';

  @override
  String get pianoChannelLabel => 'Channel:';
}
