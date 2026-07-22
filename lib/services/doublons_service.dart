import '../models/models.dart';

// Détecte les articles du catalogue qui sont probablement des doublons :
// même nom une fois normalisé (accents, casse, pluriel simple) ou noms très
// proches (petite distance de Levenshtein) — typiquement des articles créés
// séparément via le scan, la dictée vocale et la saisie manuelle.
class DoublonsService {
  static const _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i',
    'ô': 'o', 'ö': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c',
  };

  static String _normaliser(String s) {
    var t = s.toLowerCase().trim();
    _accents.forEach((k, v) => t = t.replaceAll(k, v));
    t = t.replaceAll(RegExp(r'[^a-z0-9 ]'), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.endsWith('s') && t.length > 3) t = t.substring(0, t.length - 1);
    return t;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    final la = a.length, lb = b.length;
    if (la == 0) return lb;
    if (lb == 0) return la;
    var prev = List<int>.generate(lb + 1, (j) => j);
    for (var i = 1; i <= la; i++) {
      final curr = List<int>.filled(lb + 1, 0);
      curr[0] = i;
      for (var j = 1; j <= lb; j++) {
        final cout = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cout]
            .reduce((x, y) => x < y ? x : y);
      }
      prev = curr;
    }
    return prev[lb];
  }

  static List<List<Article>> detecter(List<Article> articles) {
    final restants = [...articles];
    final groupes = <List<Article>>[];

    while (restants.isNotEmpty) {
      final base = restants.removeAt(0);
      final baseNorm = _normaliser(base.nom);
      final groupe = [base];

      restants.removeWhere((a) {
        final norm = _normaliser(a.nom);
        final proche = norm == baseNorm ||
            (baseNorm.length > 3 &&
                norm.length > 3 &&
                _levenshtein(norm, baseNorm) <= 1);
        if (proche) groupe.add(a);
        return proche;
      });

      if (groupe.length > 1) groupes.add(groupe);
    }
    return groupes;
  }
}
