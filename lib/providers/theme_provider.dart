import 'package:flutter/material.dart';
import '../services/storage_service.dart';

/// Manages the app's [ThemeMode] and persists the choice to SharedPreferences.
/// Defaults to dark mode on first launch.
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  void _loadTheme() {
    final saved = StorageService.getString('app_theme_mode');
    // Default to dark; only switch to light if explicitly saved as 'light'
    _themeMode = (saved == 'light') ? ThemeMode.light : ThemeMode.dark;
  }

  void setDarkMode(bool value) {
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
    StorageService.setString('app_theme_mode', value ? 'dark' : 'light');
    notifyListeners();
  }

  void toggleTheme() => setDarkMode(!isDark);
}
