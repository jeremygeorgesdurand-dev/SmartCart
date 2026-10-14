# Justification des permissions — SmartCart

À utiliser pour : (1) les textes affichés à l'utilisateur au moment de la
demande, (2) les explications demandées par Google Play si une permission
sensible est signalée. Chaque permission est demandée **au moment où la
fonction est utilisée**, jamais au démarrage.

## Permissions déclarées

### CAMERA (`android.permission.CAMERA`)
- **Pourquoi :** scanner un **code-barres** pour ajouter un produit au
  catalogue, et photographier un **ticket de caisse** pour en lire les prix.
- **Traitement :** la lecture du code-barres et du ticket se fait **sur
  l'appareil, hors-ligne** ; aucune image n'est envoyée sur un serveur.
- **Texte utilisateur suggéré :** « SmartCart utilise l'appareil photo pour
  scanner les codes-barres et lire vos tickets de caisse, directement sur votre
  téléphone. »

### RECORD_AUDIO (`android.permission.RECORD_AUDIO`)
- **Pourquoi :** ajouter des articles à une liste **à la voix** (dictée).
- **Traitement :** utilise la reconnaissance vocale du système ; l'app ne
  conserve aucun enregistrement.
- **Texte utilisateur suggéré :** « Le micro sert à ajouter des articles à la
  voix. Aucun enregistrement n'est conservé. »

### INTERNET (`android.permission.INTERNET`)
- **Pourquoi :** synchronisation du compte (Firebase), recherche de produits et
  de prix indicatifs, mise à jour des recettes, notifications.

## Permissions ajoutées automatiquement par les bibliothèques

### Photos et fichiers (image_picker, file_picker)
- **Aucune permission déclarée** : le choix d'une photo de ticket/recette et
  l'import/export d'une sauvegarde `.json` passent par les sélecteurs du système
  (vérifié sur l'APK construit : pas de `READ_MEDIA_IMAGES` ni de stockage).

### Autres permissions ajoutées par Firebase (non sensibles)
- `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `com.google.android.c2dm.permission.RECEIVE`
  (réception des notifications), `READ_GSERVICES` : techniques, sans demande à
  l'utilisateur.

### Notifications (`android.permission.POST_NOTIFICATIONS`, Android 13+)
- **Pourquoi :** prévenir quand une **liste collaborative** est modifiée par un
  autre membre. Facultatif : l'app fonctionne sans.

## Permissions volontairement NON demandées
Localisation, contacts, SMS, téléphone, calendrier, stockage complet des
fichiers. Leur absence est un **argument de confiance** à mettre en avant dans
la fiche Play.
