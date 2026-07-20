// Cloud Function : notifie les membres d'une liste collaborative quand
// quelqu'un ajoute/modifie/supprime un article, sauf l'auteur du
// changement (voir `lastModifiedBy`, écrit côté client dans sync_service.dart).
//
// NON DÉPLOYÉ AUTOMATIQUEMENT — nécessite :
//   1. Le plan Firebase Blaze (Cloud Functions n'est pas disponible sur Spark).
//   2. firebase-tools installé (`npm install -g firebase-tools`) + `firebase login`.
//   3. `cd functions && npm install`
//   4. Depuis la racine du projet : `firebase deploy --only functions`

const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

exports.notifierChangementListe = onDocumentWritten(
    "listes_partagees/{listeId}/articles/{itemId}",
    async (event) => {
      const {listeId} = event.params;
      const db = getFirestore();

      const listeSnap = await db.collection("listes_partagees").doc(listeId).get();
      if (!listeSnap.exists) return;

      const liste = listeSnap.data();
      const membres = liste.membres || [];
      const auteur = liste.lastModifiedBy;

      const destinataires = membres.filter((uid) => uid !== auteur);
      if (destinataires.length === 0) return;

      const tokens = [];
      for (const uid of destinataires) {
        const userSnap = await db.collection("users").doc(uid).get();
        const userTokens = userSnap.data()?.fcmTokens;
        if (Array.isArray(userTokens)) tokens.push(...userTokens);
      }
      if (tokens.length === 0) return;

      await getMessaging().sendEachForMulticast({
        tokens,
        notification: {
          title: liste.nom || "Liste de courses",
          body: "La liste a été mise à jour",
        },
        data: {listeId},
      });
    },
);
