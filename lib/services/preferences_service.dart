import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _keyAfficherStats = 'afficher_stats';
  static const _keyCouleurTheme = 'couleur_theme';

  // Charger toutes les préférences au démarrage
  Future<Map<String, dynamic>> charger() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'afficher_stats': prefs.getBool(_keyAfficherStats) ?? true,
      'couleur_theme': prefs.getString(_keyCouleurTheme) ?? 'vert',
    };
  }

  Future<void> sauvegarderAfficherStats(bool valeur) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAfficherStats, valeur);
  }

  Future<void> sauvegarderCouleurTheme(String couleur) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCouleurTheme, couleur);
  }
}
