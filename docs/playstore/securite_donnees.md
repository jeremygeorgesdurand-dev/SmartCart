# Formulaire « Sécurité des données » Google Play — SmartCart

Ce document donne, **question par question**, les réponses à recopier dans la
section **Sécurité des données** de la Play Console. Il reflète le comportement
réel de l'application (compte facultatif, traitement des photos sur l'appareil).

## Résumé à déclarer
- **Les données sont-elles chiffrées en transit ?** → **Oui** (HTTPS/TLS vers
  Firebase).
- **L'utilisateur peut-il demander la suppression de ses données ?** → **Oui**
  (suppression de compte intégrée : Réglages → Compte).

## Données collectées / partagées

Pour chaque type : *Collectée* = envoyée hors de l'appareil (ici vers Firebase).
« Partagée » = transmise à un tiers. Firebase est un **sous-traitant**, pas un
« partage » au sens Google, mais les recherches produit/prix envoient des
données à des tiers (Open Food Facts / Open Prices).

| Type de donnée | Collectée | Partagée | Finalité | Obligatoire |
|---|---|---|---|---|
| **Nom** (compte Google) | Oui | Non | Fonctionnalité de l'app ; affiché aux membres d'une liste partagée | Non (compte facultatif) |
| **Adresse e-mail** (compte Google) | Oui | Non | Gestion du compte / connexion | Non |
| **Photo de profil** (compte Google) | Oui | Non | Affichée aux membres d'une liste partagée | Non |
| **Contenu utilisateur : listes, articles, prix, recettes** | Oui (si connecté) | Non | Fonctionnalité de l'app, synchronisation, partage de liste | Non |
| **Identifiants (jeton de notification)** | Oui | Non | Notifications de listes collaboratives | Non |
| **Journaux de plantage** | Oui | Non | Diagnostics / stabilité | Non |
| **Diagnostics / performances** | Oui | Non | Diagnostics / stabilité | Non |

## Données **NON** collectées (à laisser décochées)
- **Photos** : les photos de code-barres et de tickets de caisse sont analysées
  **sur l'appareil** (lecture hors-ligne) et **ne sont pas envoyées** ni
  conservées → **non collectées**.
- **Voix / audio** : la dictée utilise la reconnaissance vocale du système ;
  l'app ne collecte ni ne stocke d'enregistrement audio → **non collecté**.
- **Localisation, contacts, SMS, santé, données financières** → non collectés.

## Recherche produit/prix (à mentionner dans la politique)
Lors d'une recherche de produit ou de prix indicatif, le **nom du produit ou
son code-barres** est envoyé à **Open Food Facts / Open Prices** (bases
communautaires). Aucune donnée personnelle n'y est jointe. À traiter comme un
appel à un service tiers, décrit dans la politique de confidentialité.

## Pratiques de sécurité (cases à cocher)
- Données chiffrées en transit : **Oui**.
- Mécanisme de suppression des données : **Oui** (compte + données cloud).
- Engagement à respecter les règles Play « Familles » : sans objet (app non
  destinée aux enfants).
