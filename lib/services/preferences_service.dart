import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _keyAfficherStats = 'afficher_stats';
  static const _keyCouleurTheme = 'couleur_theme';
  static const _keyDerniereListe = 'derniere_liste_id';

  // Dernière liste ouverte : pour rouvrir l'app directement dessus.
  Future<void> sauvegarderDerniereListe(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(_keyDerniereListe);
    } else {
      await prefs.setString(_keyDerniereListe, id);
    }
  }

  Future<String?> derniereListe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDerniereListe);
  }

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
