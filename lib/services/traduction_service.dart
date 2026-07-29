import 'dart:convert';
import 'package:http/http.dart' as http;

// Traduit du texte (anglais → français par défaut) via MyMemory, une API
// gratuite et sans clé. Spoonacular ne renvoyant ses recettes qu'en
// anglais, cette couche traduit titres, étapes et ingrédients à
// l'affichage.
//
// Limites assumées de l'offre gratuite : quota de mots par jour et débit
// bridé. On atténue par (1) un cache mémoire — un même texte n'est jamais
// traduit deux fois dans la session — et (2) la traduction groupée
// (plusieurs textes en une requête, séparés par un marqueur). En cas
// d'échec ou de quota atteint, on retombe silencieusement sur le texte
// d'origine plutôt que de bloquer l'écran.
class TraductionService {
  final http.Client _client;
  TraductionService({http.Client? client}) : _client = client ?? http.Client();

  final Map<String, String> _cache = {};

  // Marqueur inséré entre les segments d'une traduction groupée. Choisi
  // pour être préservé tel quel par le moteur de traduction (une suite de
  // caractères sans signification linguistique) et ne jamais apparaître
  // dans une vraie recette.
  static const String _sep = ' @@@ ';

  Future<String> traduire(String texte, {String de = 'en', String vers = 'fr'}) async {
    final t = texte.trim();
    if (t.isEmpty) return texte;
    final cle = '$de|$vers|$t';
    final enCache = _cache[cle];
    if (enCache != null) return enCache;

    final resultat = await _appeler(t, de, vers) ?? texte;
    _cache[cle] = resultat;
    return resultat;
  }

  // Traduit plusieurs textes. Tente d'abord une requête groupée (rapide,
  // économe en quota) ; si le découpage du résultat ne correspond pas au
  // nombre de segments envoyés (traduction ayant altéré le marqueur), on
  // retombe sur une traduction segment par segment.
  Future<List<String>> traduirePlusieurs(List<String> textes,
      {String de = 'en', String vers = 'fr'}) async {
    if (textes.isEmpty) return const [];

    final resultats = List<String>.filled(textes.length, '');
    final aTraduire = <int>[];
    for (var i = 0; i < textes.length; i++) {
      final cle = '$de|$vers|${textes[i].trim()}';
      final enCache = _cache[cle];
      if (textes[i].trim().isEmpty) {
        resultats[i] = textes[i];
      } else if (enCache != null) {
        resultats[i] = enCache;
      } else {
        aTraduire.add(i);
      }
    }
    if (aTraduire.isEmpty) return resultats;

    final segments = aTraduire.map((i) => textes[i].trim()).toList();
    final groupe = await _appeler(segments.join(_sep), de, vers);
    final morceaux = groupe?.split(_sep.trim());

    if (morceaux != null && morceaux.length == segments.length) {
      for (var k = 0; k < aTraduire.length; k++) {
        final i = aTraduire[k];
        final trad = morceaux[k].trim();
        resultats[i] = trad.isEmpty ? textes[i] : trad;
        _cache['$de|$vers|${textes[i].trim()}'] = resultats[i];
      }
    } else {
      // Repli : segment par segment (plus lent mais fiable).
      for (final i in aTraduire) {
        resultats[i] = await traduire(textes[i], de: de, vers: vers);
      }
    }
    return resultats;
  }

  // Décode les entités HTML que MyMemory (et les données Spoonacular)
  // laissent parfois passer : apostrophes, guillemets, sauts de ligne
  // (&#10;), etc.
  static String _decoderEntites(String s) {
    return s
        .replaceAll('&#39;', "'")
        .replaceAll('&#34;', '"')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAllMapped(
            RegExp(r'&#(\d+);'), (m) {
          final code = int.tryParse(m.group(1)!);
          // 10/13 = sauts de ligne → espace ; sinon on tente le caractère.
          if (code == 10 || code == 13) return ' ';
          return code != null ? String.fromCharCode(code) : m.group(0)!;
        })
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<String?> _appeler(String texte, String de, String vers) async {
    try {
      final uri = Uri.https('api.mymemory.translated.net', '/get', {
        'q': texte,
        'langpair': '$de|$vers',
      });
      final reponse =
          await _client.get(uri).timeout(const Duration(seconds: 8));
      if (reponse.statusCode != 200) return null;
      final data = jsonDecode(reponse.body);
      final trad = data['responseData']?['translatedText'];
      if (trad is String && trad.trim().isNotEmpty) {
        return _decoderEntites(trad);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
