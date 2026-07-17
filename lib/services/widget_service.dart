import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class WidgetService {
  static const _channel = MethodChannel('com.tonnom.smartcart/widget');

  static Future<void> mettreAJourWidget({
    required ListeCourses liste,
    required List<ArticleListe> items,
    required List<Article> catalogue,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final total = items.length;
    final coches = items.where((i) => i.coche).length;

    // Écrire toutes les données — Flutter ajoute "flutter." automatiquement
    // Kotlin lira "flutter.widget_liste_id" etc.
    await prefs.setString('widget_liste_id', liste.id);
    await prefs.setString('widget_liste_nom', liste.nom);
    await prefs.setInt('widget_total', total);
    await prefs.setInt('widget_coches', coches);

    // JSON complet pour la liste scrollable
    final articlesJson = items.map((item) {
      final article =
          catalogue.where((a) => a.id == item.articleId).firstOrNull;
      return {
        'id': item.id,           // articleListe.id pour cocher
        'articleId': item.articleId,
        'nom': article?.nom ?? 'Article',
        'quantite': item.quantite,
        'coche': item.coche,
      };
    }).toList();

    await prefs.setString('widget_articles_json', jsonEncode(articlesJson));

    // Forcer le rafraîchissement du widget Android
    try {
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      // Widget non installé, silencieux
    }
  }

  /// Appelé depuis MainActivity quand l'app est lancée via widget
  static void ecouterIntents(
      void Function(String action, String listeId, String articleListeId)
          onIntent) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewIntent') {
        final args = call.arguments as Map;
        onIntent(
          args['action']?.toString() ?? '',
          args['liste_id']?.toString() ?? '',
          args['article_liste_id']?.toString() ?? '',
        );
      }
    });
  }

  static Future<Map<String, String>> getWidgetIntent() async {
    try {
      final result = await _channel.invokeMethod<Map>('getWidgetIntent');
      return {
        'action': result?['action']?.toString() ?? '',
        'liste_id': result?['liste_id']?.toString() ?? '',
        'article_liste_id': result?['article_liste_id']?.toString() ?? '',
      };
    } catch (_) {
      return {'action': '', 'liste_id': '', 'article_liste_id': ''};
    }
  }

  static Future<String?> getListeWidgetId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('widget_liste_id');
  }

  static Future<void> effacerWidget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('widget_liste_id');
    await prefs.remove('widget_liste_nom');
    await prefs.remove('widget_articles_json');
    await prefs.remove('widget_total');
    await prefs.remove('widget_coches');
    try {
      await _channel.invokeMethod('updateWidget');
    } catch (_) {}
  }
}
