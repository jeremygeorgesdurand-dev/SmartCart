# GÉNÉRATION DE L'ICÔNE ET DU SPLASH SCREEN

## Étape 1 — Installer les dépendances
```
flutter pub get
```

## Étape 2 — Générer le splash screen natif
```
dart run flutter_native_splash:create
```
Cette commande lit la config dans pubspec.yaml et génère automatiquement
les fichiers dans android/app/src/main/res/

## Étape 3 — Générer les icônes Android
Installe le package flutter_launcher_icons (pas encore dans le projet) :
```
flutter pub add flutter_launcher_icons --dev
```

Ajoute dans pubspec.yaml (section flutter_launcher_icons) :
```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon.png"
  min_sdk_android: 21
  adaptive_icon_background: "#0C6755"
  adaptive_icon_foreground: "assets/icon.png"
```

Puis génère :
```
dart run flutter_launcher_icons
```

## Étape 4 — Lancer l'app
```
flutter run
```

---

## Résultat attendu

- Splash screen vert foncé (#1a1a2e) avec le logo au démarrage
- Icône verte dans le launcher Android
- Animation fade+slide à l'ouverture de l'app
- Cartes de liste qui apparaissent en cascade (staggered)
- Transition slide horizontale vers le détail d'une liste
- Check animé (rebond) en mode courses
