import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/ui_scale.dart';

/// Manages app-wide settings (persisted via SharedPreferences).
class SettingsProvider extends ChangeNotifier {
  static const _keyDisclaimerAccepted = 'disclaimer_accepted';
  static const _keyScaleFactor = 'ui_scale_factor';

  bool _disclaimerAccepted = false;
  double _scaleFactor = 1.0;

  bool get disclaimerAccepted => _disclaimerAccepted;
  double get scaleFactor => _scaleFactor;
  UIScale get uiScale => UIScale(scaleFactor: _scaleFactor);

  /// Human-readable label for current scale
  String get scaleLabel {
    if (_scaleFactor <= 0.8) return 'Compacto';
    if (_scaleFactor <= 0.95) return 'Pequeño';
    if (_scaleFactor <= 1.05) return 'Normal';
    if (_scaleFactor <= 1.2) return 'Grande';
    return 'Extra grande';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _disclaimerAccepted = prefs.getBool(_keyDisclaimerAccepted) ?? false;
    _scaleFactor = prefs.getDouble(_keyScaleFactor) ?? 1.0;
    notifyListeners();
  }

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
}
