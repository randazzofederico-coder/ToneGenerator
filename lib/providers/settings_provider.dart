import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/l10n.dart';
import '../theme/ui_scale.dart';

/// Manages app-wide settings (persisted via SharedPreferences).
class SettingsProvider extends ChangeNotifier {
  static const _keyDisclaimerAccepted = 'disclaimer_accepted';
  static const _keyScaleFactor = 'ui_scale_factor';
  static const _keyLanguage = 'settings_language';

  bool _disclaimerAccepted = false;
  double _scaleFactor = 1.0;

  /// UI language code ('es', 'en') or null to follow the system language.
  String? _languageCode;

  bool get disclaimerAccepted => _disclaimerAccepted;
  double get scaleFactor => _scaleFactor;
  UIScale get uiScale => UIScale(scaleFactor: _scaleFactor);
  String? get languageCode => _languageCode;

  /// Locale forced by the user, or null to follow the system.
  Locale? get locale => _languageCode == null ? null : Locale(_languageCode!);

  /// Human-readable label for current scale
  String scaleLabel(AppLocalizations l10n) {
    if (_scaleFactor <= 0.8) return l10n.scaleCompact;
    if (_scaleFactor <= 0.95) return l10n.scaleSmall;
    if (_scaleFactor <= 1.05) return l10n.scaleNormal;
    if (_scaleFactor <= 1.2) return l10n.scaleLarge;
    return l10n.scaleExtraLarge;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _disclaimerAccepted = prefs.getBool(_keyDisclaimerAccepted) ?? false;
    _scaleFactor = prefs.getDouble(_keyScaleFactor) ?? 1.0;
    _languageCode = prefs.getString(_keyLanguage);
    notifyListeners();
    // One-time cleanup: permission cache left by the removed legacy login.
    for (final key in _legacyPermKeys) {
      if (prefs.containsKey(key)) await prefs.remove(key);
    }
  }

  static const _legacyPermKeys = [
    'perm_has_access',
    'perm_has_profile',
    'perm_rol',
    'perm_trial_active',
    'perm_trial_days_left',
    'perm_trial_expired',
    'perm_trial_used',
    'perm_last_verified',
  ];

  Future<void> acceptDisclaimer() async {
    _disclaimerAccepted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDisclaimerAccepted, true);
    notifyListeners();
  }

  Future<void> setScaleFactor(double factor) async {
    _scaleFactor = factor.clamp(0.7, 1.3);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyScaleFactor, _scaleFactor);
    notifyListeners();
  }

  /// Sets the UI language ('es', 'en') or null to follow the system.
  Future<void> setLanguage(String? code) async {
    _languageCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_keyLanguage);
    } else {
      await prefs.setString(_keyLanguage, code);
    }
  }
}
