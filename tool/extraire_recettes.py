#!/usr/bin/env python3
"""Extraction du Livre de cuisine de Wikilivres (fr.wikibooks.org) vers un
dataset JSON local pour SmartCart.

Élargi : on énumère TOUTES les sous-pages "Livre de cuisine/..." (pas
seulement celles rangées dans la catégorie), ce qui couvre plus de recettes.
Chaque page est parsée en (titre, catégorie, portions, ingrédients, étapes,
image). On ne garde que les pages qui donnent au moins 2 ingrédients et 1
étape — le reste (pages d'index, ébauches, listes) est ignoré.

Contenu sous licence CC BY-SA (Wikilivres) ; attribution conservée dans le
JEON de sortie et affichée dans l'app.
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request

API = "https://fr.wikibooks.org/w/api.php"
UA = "SmartCartRecipeExtractor/1.0 (dataset local FR, usage personnel)"
PREFIX = "Livre de cuisine/"


def api(params):
    params = {**params, "format": "json", "formatversion": "2", "maxlag": "5"}
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    time.sleep(1.0)  # politesse : 1 req/s max
    for essai in range(6):
        try:
            with urllib.request.urlopen(req, timeout=45) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code == 429 and essai < 5:
                attente = 10 * (essai + 1)  # 10,20,30,40,50s
                print(f"  429, pause {attente}s…", file=sys.stderr)
                time.sleep(attente)
                continue
            raise
        except Exception:  # noqa
            if essai == 5:
                raise
            time.sleep(5)


def lister_pages():
    """Toutes les sous-pages Livre de cuisine/ dans l'espace principal."""
    titres = []
    cont = None
    while True:
        p = {
            "action": "query",
            "list": "allpages",
            "apprefix": PREFIX,
            "apnamespace": "0",
            "aplimit": "500",
        }
        if cont:
            p["apcontinue"] = cont
        d = api(p)
        for page in d["query"]["allpages"]:
            titres.append(page["title"])
        cont = d.get("continue", {}).get("apcontinue")
        if not cont:
            break
    return titres


def contenus(titres):
    """Wikitext par titre, par lots de 50."""
    out = {}
    for i in range(0, len(titres), 50):
        lot = titres[i:i + 50]
        d = api({
            "action": "query",
            "prop": "revisions",
            "rvprop": "content",
            "rvslots": "main",
            "titles": "|".join(lot),
        })
        for page in d["query"]["pages"]:
            revs = page.get("revisions")
            if revs:
                out[page["title"]] = revs[0]["slots"]["main"]["content"]
        time.sleep(0.2)
        print(f"  wikitext {min(i+50,len(titres))}/{len(titres)}", file=sys.stderr)
    return out


# ── Nettoyage wikitext ────────────────────────────────────────────
def _remplacer_modeles(t):
    # {{Unité|700|g}} -> "700 g" ; {{unité|1|kg}} idem ; {{nombre|2}} -> 2
    def unite(m):
        parts = [p.strip() for p in m.group(1).split("|")]
        nom = parts[0].lower()
        args = parts[1:]
        if nom in ("unité", "unite", "nombre", "nb") and args:
            return " ".join(args)
        if nom == "frac" and len(args) >= 2:
            return f"{args[0]}/{args[1]}"
        if nom in ("i", "lien", "l") and args:
            return args[-1]  # {{i|page|texte}} -> texte
        if nom in ("température", "temp") and args:
            return args[0] + " °C"
        return ""  # modèle inconnu : on retire
    # plusieurs passes pour les modèles imbriqués
    for _ in range(4):
        nouveau = re.sub(r"\{\{([^{}]*)\}\}", unite, t)
        if nouveau == t:
            break
        t = nouveau
    return t


def nettoyer(t):
    t = re.sub(r"<ref[^>]*>.*?</ref>", "", t, flags=re.S | re.I)
    t = re.sub(r"<ref[^>]*/>", "", t, flags=re.I)
    t = re.sub(r"<!--.*?-->", "", t, flags=re.S)
    t = _remplacer_modeles(t)
    # [[a|b]] -> b ; [[a]] -> a  (fichiers gérés à part avant)
    t = re.sub(r"\[\[[^\]|]*\|([^\]]*)\]\]", r"\1", t)
    t = re.sub(r"\[\[([^\]]*)\]\]", r"\1", t)
    t = re.sub(r"</?[a-zA-Z][^>]*>", "", t)  # balises HTML restantes
    t = t.replace("'''", "").replace("''", "")
    t = re.sub(r"&nbsp;", " ", t)
    t = re.sub(r"&#\d+;", " ", t)
    t = re.sub(r"\s+", " ", t).strip()
    return t.strip(" .;,")


_UNITES = (
    r"g|kg|mg|l|cl|ml|dl|litres?|grammes?|kilos?|"
    r"cuill[eè]re?s?|cuiller[eé]es?|c\.?\s*[àa]\s*[sc. ]|càs|càc|cs|cc|"
    r"tasses?|verres?|pinc[eé]es?|sachets?|gousses?|tranches?|morceaux?|"
    r"bottes?|bouquets?|feuilles?|brins?|bo[iî]tes?|pots?|noix|tours?|"
    r"traits?|gouttes?|zestes?|filets?|doses?|portions?|"
    r"tasse|pinc[eé]e"
)


def nom_court(texte):
    """Forme courte pour la liste de courses / matching frigo."""
    s = texte
    # retirer quantité en tête (nombres, fractions, ranges, ½…)
    s = re.sub(r"^[\d.,/\-–àa\s½¼¾⅓⅔⅛]+", " ", s, flags=re.I).strip()
    # retirer une unité en tête si présente
    s = re.sub(rf"^(?:{_UNITES})\b\.?", " ", s, flags=re.I).strip()
    # retirer "de/d'/du/des/de la/de l'" en tête
    s = re.sub(r"^(?:de\s+la\s+|de\s+l['’]\s*|d['’]\s*|du\s+|des\s+|de\s+|le\s+|la\s+|les\s+)",
               "", s, flags=re.I).strip()
    return s if s else texte


def categorie(titre, wikitext):
    bas = titre.lower()
    if "/boisson" in bas or "cocktail" in bas or "/apéritif" in bas:
        return "Boisson"
    t = titre.split("/")[-1].lower()
    desserts = ("gâteau", "gateau", "tarte", "crème", "creme", "mousse",
                "clafoutis", "biscuit", "cookie", "crêpe", "crepe", "gaufre",
                "flan", "glace", "sorbet", "confiture", "compote", "beignet",
                "cake", "muffin", "brownie", "pudding", "far ", "madeleine",
                "sablé", "sable", "macaron", "chausson", "strudel", "baba")
    if any(k in t for k in desserts):
        return "Dessert"
    entrees = ("salade", "soupe", "velouté", "veloute", "potage", "tartare",
               "terrine", "quiche", "gaspacho", "houmous", "tapenade",
               "anchoïade", "anchoiade", "tzatziki")
    if any(k in t for k in entrees):
        return "Entrée"
    return "Plat"


def portions(wikitext):
    m = re.search(r"[Pp]our\s+(\d{1,2})\s+(?:personnes?|parts?|convives?)", wikitext)
    if m:
        return int(m.group(1))
    m = re.search(r"(\d{1,2})\s+(?:personnes?|parts?)\b", wikitext)
    if m:
        return int(m.group(1))
    return 4


def _corpus_section(wikitext, motifs_titre):
    """Corps de la 1re section dont le titre matche un des motifs, ou None."""
    blocs = re.split(r"(?m)^==+\s*(.+?)\s*==+\s*$", wikitext)
    for i in range(1, len(blocs), 2):
        titre = blocs[i].lower()
        if any(m in titre for m in motifs_titre):
            return blocs[i + 1] if i + 1 < len(blocs) else ""
    return None


def _lignes_prefixe(corpus, prefixe):
    lignes = []
    for ligne in corpus.splitlines():
        ligne = ligne.strip()
        if ligne.startswith(prefixe):
            contenu = ligne.lstrip(prefixe).strip()
            if contenu:
                lignes.append(contenu)
    return lignes


def _lignes_prose(corpus):
    """Lignes de texte "normal" (ni puce, ni titre, ni gabarit) : sert de
    repli quand les étapes sont rédigées en paragraphes plutôt qu'en liste
    numérotée (fréquent, notamment pour les cocktails)."""
    out = []
    for ligne in corpus.splitlines():
        l = ligne.strip()
        if not l:
            continue
        if l[0] in "*#:;=|!{}" or l.startswith(("[[Fichier", "[[Image",
                                                "[[File", "[[Catégorie")):
            continue
        out.append(l)
    return out


def image_fichier(wikitext):
    m = re.search(r"\[\[\s*(?:Fichier|Image|File)\s*:\s*([^\]|]+)", wikitext, re.I)
    if m:
        return m.group(1).strip()
    return None


_MOTIFS_ETAPES = ("préparation", "preparation", "réalisation", "realisation",
                  "recette", "instructions", "méthode", "methode",
                  "confection", "montage")


def parser(titre, wikitext):
    # Ingrédients : puces de la section "Ingrédients", sinon puces du texte.
    corpus_ing = _corpus_section(wikitext, ("ingrédient", "ingredient"))
    ings_brut = _lignes_prefixe(
        corpus_ing if corpus_ing is not None else wikitext, "*")

    # Étapes : lignes numérotées de la section "Préparation" ; à défaut, ses
    # paragraphes en prose ; à défaut, lignes numérotées du texte entier.
    corpus_etapes = _corpus_section(wikitext, _MOTIFS_ETAPES)
    if corpus_etapes is not None:
        etapes_brut = _lignes_prefixe(corpus_etapes, "#")
        if not etapes_brut:
            etapes_brut = _lignes_prose(corpus_etapes)
    else:
        etapes_brut = _lignes_prefixe(wikitext, "#")

    ingredients = []
    for l in ings_brut:
        texte = nettoyer(l)
        if texte and len(texte) <= 120:
            ingredients.append({"texte": texte, "nom": nom_court(texte)})
    etapes = []
    for l in etapes_brut:
        texte = nettoyer(l)
        if texte:
            etapes.append(texte)
    if len(ingredients) < 2 or len(etapes) < 1:
        return None
    return {
        "titre": titre.split("/")[-1],
        "categorie": categorie(titre, wikitext),
        "portions": portions(wikitext),
        "ingredients": ingredients,
        "etapes": etapes,
        "url": "https://fr.wikibooks.org/wiki/" + urllib.parse.quote(titre.replace(" ", "_")),
        "_fichier": image_fichier(wikitext),
    }


def resoudre_images(recettes):
    """Récupère les URLs de vignettes (500px) via imageinfo, par lots."""
    fichiers = sorted({r["_fichier"] for r in recettes if r["_fichier"]})
    url_par_fichier = {}
    for i in range(0, len(fichiers), 50):
        lot = fichiers[i:i + 50]
        titres = ["File:" + f for f in lot]
        d = api({
            "action": "query",
            "prop": "imageinfo",
            "iiprop": "url",
            "iiurlwidth": "500",
            "titles": "|".join(titres),
        })
        for page in d["query"].get("pages", []):
            ii = page.get("imageinfo")
            if ii and ii[0].get("thumburl"):
                nom = page["title"].split(":", 1)[1]
                url_par_fichier[nom] = ii[0]["thumburl"]
        time.sleep(0.2)
        print(f"  images {min(i+50,len(fichiers))}/{len(fichiers)}", file=sys.stderr)
    for r in recettes:
        f = r.pop("_fichier", None)
        r["image"] = url_par_fichier.get(f) if f else None


def main():
    print("Listing des pages…", file=sys.stderr)
    titres = lister_pages()
    # écarter les pages qui ne sont pas des recettes
    ignore = ("/liste", "/annexe", "/introduction", "/glossaire", "/index",
              "/modèle", "/aide", "/sommaire", "/ustensile", "/technique",
              "/lexique", "/catégorie")
    titres = [t for t in titres
              if t != "Livre de cuisine"
              and not any(k in t.lower() for k in ignore)]
    print(f"{len(titres)} pages candidates", file=sys.stderr)

    wt = contenus(titres)
    recettes = []
    for i, t in enumerate(titres):
        w = wt.get(t)
        if not w:
            continue
        r = parser(t, w)
        if r:
            r["id"] = "wb_%04d" % len(recettes)
            recettes.append(r)
    print(f"{len(recettes)} recettes valides parsées", file=sys.stderr)

    resoudre_images(recettes)
    avec_img = sum(1 for r in recettes if r.get("image"))
    print(f"{avec_img} recettes avec image", file=sys.stderr)

    recettes_out = [{
        "titre": r["titre"], "categorie": r["categorie"],
        "portions": r["portions"], "image": r.get("image"),
        "ingredients": r["ingredients"], "etapes": r["etapes"], "url": r["url"],
    } for r in recettes]

    # ── Fusion avec le dataset existant (on ne fait QUE grandir) ──────
    # Clé = titre normalisé ; pour un même titre, on garde l'entrée la plus
    # riche (avec image de préférence, puis le plus d'ingrédients+étapes).
    def cle(r):
        return re.sub(r"\s+", " ", r["titre"].strip().lower())

    def score(r):
        return (1 if r.get("image") else 0,
                len(r.get("ingredients", [])) + len(r.get("etapes", [])))

    fusion = {}
    try:
        anciennes = json.load(open("assets/recettes_fr.json", encoding="utf-8"))
        for r in anciennes.get("recettes", []):
            fusion[cle(r)] = r
        print(f"{len(fusion)} recettes existantes chargées pour fusion",
              file=sys.stderr)
    except FileNotFoundError:
        pass
    for r in recettes_out:
        k = cle(r)
        if k not in fusion or score(r) > score(fusion[k]):
            fusion[k] = r

    finales = sorted(fusion.values(), key=lambda r: r["titre"].lower())
    for i, r in enumerate(finales):
        r["id"] = "wb_%04d" % i
        # ordre de clés stable
    recettes_out = [{
        "id": r["id"], "titre": r["titre"], "categorie": r["categorie"],
        "portions": r["portions"], "image": r.get("image"),
        "ingredients": r["ingredients"], "etapes": r["etapes"], "url": r["url"],
    } for r in finales]
    print(f"{len(recettes_out)} recettes après fusion "
          f"({sum(1 for r in recettes_out if r.get('image'))} avec image)",
          file=sys.stderr)

    data = {
        "source": "Wikilivres — Livre de cuisine",
        "licence": "CC BY-SA",
        "licence_url": "https://creativecommons.org/licenses/by-sa/3.0/",
        "genere_le": time.strftime("%Y-%m-%d"),
        "recettes": recettes_out,
    }
    with open("assets/recettes_fr.json", "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print(f"Écrit assets/recettes_fr.json ({len(recettes_out)} recettes)", file=sys.stderr)


if __name__ == "__main__":
    main()
