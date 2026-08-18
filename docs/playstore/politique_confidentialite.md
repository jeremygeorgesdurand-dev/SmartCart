# Politique de confidentialité — SmartCart

**Dernière mise à jour : 18 août 2026**

SmartCart (« l'application ») est une application de listes de courses. Cette
politique explique quelles données l'application traite, pourquoi, et vos
droits. Elle est rédigée pour être publiée à une adresse web publique (par
exemple GitHub Pages) et renseignée dans la fiche Google Play.

> **À compléter avant publication :** adresse e-mail de contact et, si besoin,
> l'identité de l'éditeur. Remplacez `VOTRE_EMAIL` ci-dessous.

## 1. Responsable du traitement
L'éditeur de SmartCart. Contact : `VOTRE_EMAIL`.

## 2. Données traitées et finalités

### a) Données que vous saisissez (au cœur de l'app)
- **Vos listes de courses, votre catalogue d'articles, catégories, rayons,
  prix, recettes.** Stockés **localement** sur votre appareil. Si vous vous
  connectez avec un compte Google, ils sont aussi **synchronisés** via Google
  Firebase (Firestore) pour être retrouvés sur vos appareils et partagés avec
  les personnes que vous invitez sur une liste collaborative.

### b) Compte (facultatif)
- **Connexion Google** : si vous choisissez de vous connecter, nous recevons de
  Google votre **nom**, **adresse e-mail** et **photo de profil**, via Firebase
  Authentication. Le nom et la photo peuvent être affichés aux autres membres
  d'une liste collaborative que vous partagez. L'application fonctionne aussi
  **sans compte**, entièrement hors-ligne.

### c) Notifications
- Si vous l'autorisez, un **jeton de notification** (Firebase Cloud Messaging)
  permet de vous prévenir quand une liste collaborative est modifiée.

### d) Diagnostics
- **Rapports de plantage et de performance** (Firebase Crashlytics) pour
  corriger les bugs. Ils peuvent inclure des identifiants techniques de
  l'appareil et l'état de l'app au moment du plantage, pas le contenu de vos
  listes.

### e) Photos
- Les photos que vous prenez (**code-barres**, **ticket de caisse**) sont
  analysées **sur votre appareil uniquement** (lecture de code-barres et
  reconnaissance de texte hors-ligne). Elles **ne sont pas envoyées** sur nos
  serveurs ni conservées après l'analyse.

## 3. Services tiers
- **Google Firebase** (Authentication, Firestore, Cloud Messaging, Crashlytics,
  App Check) — hébergement, synchronisation, notifications, diagnostics.
- **Open Food Facts** et **Open Prices** — lorsque vous recherchez un produit
  ou un prix indicatif, le **nom du produit ou son code-barres** est envoyé à
  ces bases communautaires pour obtenir des informations. Aucune donnée
  personnelle n'y est jointe.
- **Recettes** — le dataset de recettes est embarqué dans l'app ; sa mise à
  jour télécharge un fichier public depuis le dépôt du projet.

## 4. Partage des données
Nous **ne vendons pas** vos données. Elles sont partagées uniquement :
- avec **Google Firebase**, en tant que sous-traitant technique ;
- avec les **membres d'une liste collaborative** que **vous** invitez (contenu
  de cette liste, et votre nom/photo de profil).

## 5. Conservation et suppression
- Les données locales restent sur votre appareil tant que l'app est installée.
- Les données synchronisées restent tant que votre compte existe.
- Vous pouvez **supprimer votre compte et toutes vos données cloud** depuis
  l'application (Réglages → Compte → Supprimer le compte), conformément au RGPD.

## 6. Sécurité
Les échanges avec Firebase sont chiffrés (HTTPS/TLS). L'accès aux données cloud
est restreint par des **règles de sécurité Firestore** et **Firebase App
Check**.

## 7. Enfants
L'application n'est pas destinée aux enfants de moins de 13 ans et ne leur est
pas spécifiquement adressée.

## 8. Vos droits (RGPD)
Accès, rectification, effacement, portabilité, opposition. Pour l'effacement,
utilisez la suppression de compte intégrée ou écrivez à `VOTRE_EMAIL`.

## 9. Modifications
Cette politique peut évoluer ; la date en tête indique la dernière version.
