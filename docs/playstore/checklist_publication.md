# Checklist de publication — SmartCart

Légende : ✅ fait · ⬜ à faire par toi · ⚠️ décision à prendre **avant** de continuer.

## 0. État du projet (14 octobre 2026)
| Point | État |
|---|---|
| SDK cible Android | ✅ 36 |
| Format Play (AAB) | ⬜ à construire avec la vraie clé (voir §2) |
| Politique de confidentialité + page de suppression de compte | ✅ rédigées (`docs/`) — ⬜ mettre en ligne (§4) et renseigner l'e-mail |
| Formulaire « Sécurité des données », permissions | ✅ `securite_donnees.md`, `permissions.md` |
| Fiche (textes, icône, visuel 1024×500) | ✅ — ⬜ captures d'écran |
| Suppression de compte complète | ✅ corrigée en v1.31.1 (voir §6) |
| Signature de release | ❌ **absente** : les APK sont signés avec la clé de *debug* |
| Identifiant d'application | ⚠️ `com.tonnom.smartcart` = valeur provisoire |

## 1. ⚠️ Choisir l'identifiant d'application (maintenant)
L'identifiant (`applicationId`) est **définitif après la première publication**.
`com.tonnom.smartcart` est un placeholder. Exemple de format : `com.tonnom.smartcart`
→ `com.<ton-nom>.smartcart`.

Le changer implique : nouveau renommage du paquet Android/Kotlin (widget compris),
**nouvelle application Android enregistrée dans Firebase** (nouveau
`google-services.json`), et pour tes téléphones : l'appli devient une *autre*
appli (données locales non reprises → exporter via **Sauvegarde** avant).
Mieux vaut le faire **maintenant**, avant toute publication. → Dis-moi l'identifiant
voulu et je fais le renommage.

## 2. Clé de signature (indispensable)
1. Créer la clé d'envoi (une seule fois, à conserver **précieusement** — mot de
   passe + fichier à sauvegarder hors de l'ordinateur) :
   ```
   keytool -genkey -v -keystore ~/smartcart-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Créer `android/key.properties` (déjà ignoré par git, ne jamais le publier) :
   ```
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=/Users/jeremy/smartcart-upload.jks
   ```
3. Construire le bundle : `flutter build appbundle --release`
   → `build/app/outputs/bundle/release/app-release.aab`.

⚠️ **Conséquence sur tes téléphones** : une appli signée avec une autre clé ne
peut pas s'installer par-dessus l'ancienne (« signature différente »). Avant de
passer à la version Play : **Sauvegarde** (Réglages) → désinstaller → installer →
restaurer. Les données du compte Google se resynchronisent seules.

## 3. Firebase (sinon la connexion Google échoue sur la version Play)
Play re-signe l'appli avec **sa propre clé** : il faut déclarer ses empreintes.
1. Play Console → *Intégrité de l'appli* → copier les empreintes **SHA-1 et SHA-256**
   de la clé de signature d'appli (et celles de la clé d'envoi).
2. Console Firebase → Paramètres du projet → ton app Android → *Ajouter une empreinte*.
3. Retélécharger `google-services.json` et le remplacer dans `android/app/`.
4. Firebase **App Check** : activer le fournisseur *Play Integrity* et lier le
   projet à la Play Console (le code l'utilise déjà en version publiée).
5. Règles Firestore : déjà publiées — **aucune règle à modifier** pour cette
   version (vérifié).

## 4. Mettre en ligne la politique de confidentialité
1. Remplacer `VOTRE_EMAIL` (3 fichiers : `docs/index.html`,
   `docs/suppression-compte.html`, `docs/playstore/politique_confidentialite.md`)
   par ton e-mail de contact **public** — c'est une adresse que tout le monde pourra voir.
2. GitHub → dépôt SmartCart → *Settings* → *Pages* → *Deploy from a branch* →
   `main` / dossier `/docs`.
3. Vérifier que ces deux adresses s'ouvrent (la première est aujourd'hui en 404) :
   - `https://jeremygeorgesdurand-dev.github.io/SmartCart/`
   - `https://jeremygeorgesdurand-dev.github.io/SmartCart/suppression-compte.html`

⚠️ Le dépôt est **public** et l'appli télécharge sa liste de recettes depuis
`raw.githubusercontent.com/…/main/assets/recettes_fr.json` : ne pas rendre le
dépôt privé ni renommer la branche `main`, sinon la mise à jour des recettes casse.

## 5. Compte et Play Console
1. Créer un compte développeur Google Play (paiement unique d'environ 25 $,
   vérification d'identité).
2. **Compte personnel récent** : Google exigeait (règle de 2023, à revérifier dans
   la console) un **test fermé avec au moins 12 testeurs pendant 14 jours
   consécutifs** avant de pouvoir demander l'accès à la production. Prévoir ce
   délai et recruter des testeurs (famille, amis) dès que possible.
3. Créer l'application → remplir la fiche avec `fiche_store.md` → déclarations
   (confidentialité, sécurité des données avec `securite_donnees.md`, classification,
   public cible, publicités : non, suppression de compte : URL du §4).
4. Envoyer l'AAB en **test interne** d'abord, tester l'installation depuis le Store
   (connexion Google, partage, widget, scan, micro), puis test fermé, puis production.

## 6. Suppression de compte (exigence du Store) — corrigée
Constat avant correction : un propriétaire d'une liste partagée avec d'autres ne
pouvait **pas** supprimer son compte (les règles interdisent au propriétaire de
quitter la liste ; la suppression s'arrêtait en cours de route). Les restes
(catalogue partagé, profils partagés, listes dont on est le dernier membre)
n'étaient pas effacés.
Maintenant : propriété transmise à un autre membre, puis départ ; liste supprimée
si on en est le dernier membre ; catalogue et profils partagés supprimés avec leurs
codes. Testé sur Firestore en mémoire (les règles de sécurité réelles, elles, ont
été relues à la main mais **pas exécutées** — à vérifier avec un compte de test).

## 7. Plus tard (non bloquant)
- Message d'invitation : ajouter le lien Play Store une fois l'appli publiée.
- Lien d'invitation `https://` (App Links) qui ouvre l'appli ou renvoie au Store :
  demande un nom de domaine et un fichier `assetlinks.json` ; le lien
  `smartcart://` et le QR code fonctionnent déjà en attendant.
- Notifications push : le jeton est enregistré mais aucune notification n'est
  encore envoyée (la politique dit « prévu pour… »).
