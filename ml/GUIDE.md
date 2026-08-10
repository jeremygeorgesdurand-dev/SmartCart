# Guide du Machine Learning — reconnaissance d'aliments pour SmartCart

Ce document explique **tout le processus de machine learning (ML)**, de zéro,
appliqué à notre objectif : reconnaître des aliments sur une photo. Il est
écrit pour être lu sans connaissance préalable. Le notebook
[`entrainement_aliments.ipynb`](entrainement_aliments.ipynb) met en pratique
la **phase 1** (un aliment par photo).

Objectif en deux phases :
- **Phase 1** — *Classification* : une photo = **un** aliment centré → « c'est une courgette ».
- **Phase 2** — *Détection* : une photo de frigo = **plusieurs** aliments → « une courgette ici, un yaourt là, des œufs là ».

Ces deux phases sont **deux problèmes de ML différents**. On commence par la 1,
qui est accessible ; la 2 est expliquée en fin de document.

---

## 1. C'est quoi le machine learning, vraiment ?

En programmation classique, **tu écris les règles**. Pour reconnaître une
banane tu devrais écrire : « si c'est jaune, allongé, courbé… ». Impossible à
tenir : il y a mille formes de bananes, éclairages, arrière-plans.

En ML, **on ne donne pas les règles** : on donne des **exemples**, et le
programme **trouve les règles tout seul**. On lui montre 5 000 photos de
bananes étiquetées « banane », 5 000 de pommes étiquetées « pomme », etc., et
il apprend à distinguer. C'est un renversement : *données + réponses → règles*,
au lieu de *données + règles → réponses*.

Le résultat de cet apprentissage s'appelle un **modèle** : un gros fichier de
nombres (les « poids ») qui, appliqués à une image, sortent une prédiction.

---

## 2. Le vocabulaire essentiel

| Terme | Ce que ça veut dire |
|---|---|
| **Modèle** | Le « cerveau » entraîné. Prend une image en entrée, sort une prédiction. |
| **Features** (caractéristiques) | Ce que le modèle « regarde » : contours, textures, couleurs, formes. Il les découvre seul. |
| **Label** (étiquette) | La bonne réponse fournie pendant l'entraînement : « banane ». |
| **Entraînement** (training) | La phase où le modèle apprend à partir des exemples étiquetés. |
| **Inférence** | L'utilisation du modèle entraîné sur une nouvelle image (dans l'app, sur le téléphone). |
| **Dataset** | L'ensemble des images + labels. |
| **Classe** | Une catégorie possible de sortie (pomme, banane, carotte…). |

---

## 3. Les données : le carburant (et le vrai travail)

**Règle d'or du ML : le modèle ne vaut jamais mieux que ses données.** 80 % du
travail réel, c'est la donnée, pas l'algorithme.

### 3.1 Collecte et étiquetage
Il faut beaucoup d'images **étiquetées** : rangées par dossier
(`pomme/img1.jpg`, `pomme/img2.jpg`, `banane/…`). Le nom du dossier = le label.
Pour la phase 1, on **réutilise un dataset public déjà étiqueté** (Fruits-360),
ce qui nous évite l'étape la plus longue. Pour couvrir des produits spécifiques
(un yaourt d'une marque), il faudrait photographier et étiqueter soi-même.

### 3.2 Le découpage train / validation / test
On ne donne **pas** toutes les images à l'entraînement. On coupe en trois :

- **Entraînement (~70 %)** : le modèle apprend dessus.
- **Validation (~15 %)** : pendant l'entraînement, on vérifie sur ces images
  *jamais apprises* si le modèle progresse **vraiment** (ou s'il triche, voir §5).
- **Test (~15 %)** : jamais vues, servent au **verdict final** honnête.

Pourquoi ? Parce qu'un modèle peut « réciter par cœur » les images
d'entraînement sans rien comprendre. Le seul juge valable, ce sont des images
qu'il n'a jamais vues.

---

## 4. L'apprentissage : comment le modèle « apprend » ?

Intuition, sans mathématiques lourdes.

Au départ, le modèle est **nul** : ses poids sont aléatoires, il répond au
hasard. L'entraînement répète en boucle ces 4 étapes :

1. **Prédiction** : on lui montre une image, il devine (« 70 % banane, 30 % pomme »).
2. **Erreur** (la *loss*) : on compare à la vraie réponse. Un nombre mesure à
   quel point il s'est trompé. Grand = très faux, petit = presque juste.
3. **Correction** (la *rétropropagation* / *descente de gradient*) : on ajuste
   légèrement **tous les poids** dans la direction qui **réduit l'erreur**.
   Image mentale : descendre une colline dans le brouillard en faisant un petit
   pas vers le bas à chaque fois — la vallée, c'est l'erreur minimale.
4. **On recommence** avec l'image suivante.

Quelques mots que tu verras défiler dans le notebook :
- **Epoch** (époque) : un passage complet sur **toutes** les images d'entraînement.
  On en fait plusieurs (5, 10…). À chaque époque, le modèle s'améliore un peu.
- **Batch** (lot) : on ne traite pas les images une par une mais par paquets
  (ex. 32), plus efficace.
- **Learning rate** (taux d'apprentissage) : la **taille du pas** de correction.
  Trop grand → on saute par-dessus la vallée ; trop petit → c'est interminable.
- **Accuracy** (précision) : le % de bonnes réponses. C'est ce qu'on regarde monter.

À la fin, l'erreur est basse, la précision haute : le modèle a **appris**.

---

## 5. Le surapprentissage (overfitting) : le piège n°1

Le danger central du ML. Le modèle peut **mémoriser** les images
d'entraînement au lieu de **généraliser**. C'est comme un élève qui apprend les
corrigés par cœur mais échoue dès que l'énoncé change.

**Comment on le repère ?** On surveille deux courbes pendant l'entraînement :
- précision sur l'**entraînement** : elle monte, monte…
- précision sur la **validation** : si elle **stagne ou redescend** alors que
  celle d'entraînement continue de monter → le modèle triche = surapprentissage.

**Comment on le combat ?**
- **Plus de données** (le meilleur remède).
- **Data augmentation** : on crée des variantes des images à la volée (rotation,
  zoom, luminosité, miroir). Le modèle voit « la même banane » sous 20 angles →
  il apprend la banane, pas une photo précise.
- **Dropout** : pendant l'entraînement on « éteint » au hasard une partie du
  réseau à chaque étape, ce qui l'empêche de trop se reposer sur des détails.
- **Early stopping** : on arrête dès que la validation cesse de progresser.

---

## 6. Le transfer learning : on ne part JAMAIS de zéro

Entraîner un réseau de vision depuis rien demande des **millions** d'images et
des semaines de calcul. On ne le fait pas. À la place :

On prend un modèle **déjà entraîné** sur des millions d'images générales
(**MobileNet**, **EfficientNet**…). Il « sait déjà voir » : détecter des
contours, textures, formes. On **garde tout ce savoir** et on ne ré-entraîne
que **la dernière couche** (celle qui décide « pomme vs banane ») sur nos
quelques milliers d'images d'aliments.

C'est comme embaucher quelqu'un qui sait déjà cuisiner et lui apprendre juste
**tes** recettes, au lieu de former un débutant total. Résultat : entraînement
en **minutes** au lieu de semaines, avec **peu** de données. C'est la technique
qu'utilise notre notebook, et la raison pour laquelle ce projet est faisable
gratuitement.

---

## 7. Évaluer honnêtement le modèle

La précision globale ne suffit pas. Outils :
- **Matrice de confusion** : un tableau qui montre *quoi* est confondu avec
  *quoi* (« il prend souvent le citron pour une pomme verte »). Très instructif.
- **Test sur images réelles** : les tiennes, prises avec ton téléphone, dans ta
  cuisine — pas les images « propres » du dataset. C'est le vrai test.

Un modèle à 95 % sur le dataset mais 50 % sur tes photos de frigo = le dataset
ne ressemble pas à la réalité. C'est fréquent et c'est un signal, pas un échec.

---

## 8. Exporter pour le téléphone : TensorFlow Lite

Le modèle entraîné est trop lourd/lent pour un téléphone tel quel. On le
**convertit en `.tflite`** : un format compact et optimisé pour mobile
(**quantization** : on réduit la précision des nombres, ex. de 32 à 8 bits, ce
qui divise la taille par ~4 avec une perte de précision minime).

Sortie : un fichier de quelques Mo. C'est **le seul livrable** du notebook. On
le glisse dans l'app Flutter (`assets/`), et le paquet `tflite_flutter` le fait
tourner **sur l'appareil**, hors-ligne, gratuitement.

Le flux dans l'app (phase 1) : caméra → photo d'un aliment → le modèle sort
« courgette 92 % » → on propose de l'ajouter au catalogue/liste.

---

## 9. Le cycle du ML (le processus « automatisé »)

Le ML n'est pas linéaire, c'est une **boucle** qu'on répète pour améliorer :

```
   ┌───────────────────────────────────────────────┐
   │  1. Rassembler / étiqueter des données         │
   │  2. Entraîner (transfer learning)              │
   │  3. Évaluer (validation + test + vraies photos)│
   │  4. Diagnostiquer les erreurs                  │
   │  5. Corriger : + de données, augmentation,     │
   │     ajuster les réglages…                      │
   └──────────────┬────────────────────────────────┘
                  └──── on recommence ──────┘
```

« Automatiser l'apprentissage » = rendre cette boucle **reproductible en un
clic** : le notebook fait 1→2→3 automatiquement à chaque exécution. Quand tu
ajoutes des images ou changes la liste d'aliments, tu **relances tout** et tu
obtiens un nouveau `.tflite`. On peut aussi programmer un ré-entraînement
périodique, mais au début, relancer le notebook à la main suffit largement.

---

## 10. Phase 2 : plusieurs aliments sur une même photo

C'est un **autre problème**, plus difficile — important de comprendre pourquoi.

**Phase 1 = classification** : « cette image, c'est *quoi* ? » → **une** réponse.
Elle suppose **un objet** qui remplit l'image.

**Phase 2 = détection d'objets** : « *où* sont les objets et *quels* sont-ils ? »
→ plusieurs réponses, chacune avec une **boîte** (rectangle) autour de l'objet :
`courgette [x,y,largeur,hauteur]`, `yaourt [...]`, `œufs [...]`.

Ce que ça change, concrètement :

1. **Les données sont bien plus coûteuses.** Il ne suffit plus de ranger les
   images par dossier. Il faut **dessiner à la main un rectangle** autour de
   *chaque* objet de *chaque* photo et l'étiqueter (outils : Roboflow, LabelImg,
   CVAT). Annoter des milliers de photos de frigo = un travail énorme. C'est le
   vrai goulot d'étranglement de la phase 2.
2. **Le modèle est différent** : on utilise une architecture de *détection*
   (**YOLO** — ex. YOLOv8, ou EfficientDet, ou MediaPipe Object Detector), pas
   un simple classifieur.
3. **La scène est difficile** : dans un frigo, les objets se **chevauchent**,
   sont partiellement cachés, mal éclairés, vus de biais. Même les modèles pros
   galèrent là-dessus.

**Chemins réalistes pour la phase 2**, du plus simple au plus ambitieux :
- **(a) Réutiliser un détecteur pré-entraîné** (YOLOv8 entraîné sur COCO, qui
  connaît déjà « banana », « apple », « orange », « bottle »…). Zéro
  entraînement, mais vocabulaire limité et générique. Bon point de départ pour
  voir la détection multi-objets marcher.
- **(b) Fine-tuner YOLOv8** sur **tes** images de frigo annotées. Meilleur, mais
  demande le travail d'annotation ci-dessus. C'est le vrai « projet ML complet ».
- **(c) API cloud** (Google Vision) : la plus précise sur une scène réelle,
  mais payante au-delà du quota gratuit et non hors-ligne.

**Recommandation** : réussir d'abord la **phase 1** (classification, notebook
fourni) — tu y apprends tout le socle du ML. Puis attaquer la phase 2 par
l'option **(a)** pour voir la détection en action sans annoter, avant
d'éventuellement investir dans **(b)**.

---

## 11. Limites honnêtes & bonnes pratiques

- **Périmètre** : un modèle ne reconnaît que ce qu'il a **appris**. Les datasets
  libres couvrent surtout **fruits et légumes** (objets « nus »), beaucoup moins
  les **produits emballés** (un pot de yaourt d'une marque). Pour ceux-là, le
  code-barres (déjà dans l'app) reste bien plus fiable qu'une photo.
- **Réalisme des données** : entraîne/teste avec des photos proches de l'usage
  réel (ta cuisine), sinon la précision annoncée est trompeuse.
- **Confiance** : le modèle sort toujours un score (%). En dessous d'un seuil
  (ex. 60 %), mieux vaut afficher « pas sûr » que d'inventer.
- **Vie privée** : tout est **local** (sur le téléphone). Rien n'est envoyé sur
  un serveur — c'est un atout à garder.

---

## 12. Par où commencer

1. Ouvre [`entrainement_aliments.ipynb`](entrainement_aliments.ipynb) dans
   **Google Colab** (colab.research.google.com → Importer → ce fichier), ou
   dans l'IDE.
2. Lis les cellules dans l'ordre, clique ▶ sur chacune.
3. À la fin, tu télécharges `aliments.tflite` + `labels.txt`.
4. On les intègre ensuite dans l'app (écran « scanner un aliment »).

Le notebook est commenté en français, étape par étape, en suivant exactement
les notions de ce guide (§3 données → §4 entraînement → §5 anti-surapprentissage
→ §6 transfer learning → §7 évaluation → §8 export TFLite).
