# Configuration permission_handler pour Android

## Étape 1 — Dans android/app/build.gradle
Ajouter dans la section `android { defaultConfig { ... } }` :

```gradle
android {
    defaultConfig {
        // ... autres configs existantes ...
        minSdkVersion 21   // doit être au moins 21
    }
}
```

## Étape 2 — Dans android/app/src/main/AndroidManifest.xml
Ces permissions doivent déjà être présentes (vérifier) :

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

## Étape 3 — flutter pub get
```
flutter pub get
flutter run
```

L'app demandera automatiquement la permission micro au premier usage.
