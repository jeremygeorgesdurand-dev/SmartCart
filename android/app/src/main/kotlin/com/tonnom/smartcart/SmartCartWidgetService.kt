package com.tonnom.smartcart

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService

// Fournit le contenu défilable de la liste dans le widget écran d'accueil :
// avant, seules les 6 premières lignes (triées alphabétiquement) étaient
// affichées en dur, sans aucun moyen de voir le reste. Un RemoteViewsService
// + une ListView permettent un vrai défilement, avec en prime un tri par
// rayon (comme le Mode Courses de l'app) en plus du tri alphabétique.
class SmartCartWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val listeId = intent.getStringExtra("liste_id") ?: ""
        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        return SmartCartRemoteViewsFactory(applicationContext, listeId, widgetId)
    }
}

private class SmartCartRemoteViewsFactory(
    private val context: android.content.Context,
    private val listeId: String,
    private val widgetId: Int,
) : RemoteViewsService.RemoteViewsFactory {

    companion object {
        private const val TAG = "SmartCartWidgetSvc"
    }

    private sealed class Ligne {
        data class Entete(val nom: String) : Ligne()
        data class Article(
            val id: String,
            val nom: String,
            val quantite: Int,
            val unite: String?,
            val coche: Boolean,
        ) : Ligne()
    }

    private var lignes: List<Ligne> = emptyList()

    override fun onCreate() {}
    override fun onDestroy() {}
    override fun getCount() = lignes.size
    override fun getViewTypeCount() = 2
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = false
    override fun getLoadingView(): RemoteViews? = null

    // Rechargé par le système à chaque notifyAppWidgetViewDataChanged() —
    // c'est ici qu'on relit la base et applique le tri courant.
    override fun onDataSetChanged() {
        if (listeId.isEmpty()) {
            lignes = emptyList()
            return
        }
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences", android.content.Context.MODE_PRIVATE)
        val tri = (prefs.all["widget_tri"] as? String) ?: "alpha"

        try {
            val dbFile = context.getDatabasePath("smartcart.db")
            if (!dbFile.exists()) { lignes = emptyList(); return }
            val db = SQLiteDatabase.openDatabase(
                dbFile.path, null, SQLiteDatabase.OPEN_READONLY)

            data class Art(
                val id: String, val nom: String, val quantite: Int,
                val unite: String?, val coche: Boolean,
                val rayonNom: String?, val rayonOrdre: Int,
            )

            val cursor = db.rawQuery(
                "SELECT al.id, a.nom, al.quantite, al.unite, al.coche, " +
                    "r.nom, r.ordre " +
                    "FROM articles_liste al " +
                    "JOIN articles a ON a.id = al.articleId " +
                    "LEFT JOIN rayons r ON r.id = a.rayonId " +
                    "WHERE al.listeId = ?",
                arrayOf(listeId))
            val tout = mutableListOf<Art>()
            while (cursor.moveToNext()) {
                tout.add(Art(
                    id = cursor.getString(0),
                    nom = cursor.getString(1) ?: "?",
                    quantite = cursor.getInt(2),
                    unite = cursor.getString(3),
                    coche = cursor.getInt(4) == 1,
                    rayonNom = cursor.getString(5),
                    rayonOrdre = if (cursor.isNull(6)) 99 else cursor.getInt(6),
                ))
            }
            cursor.close()
            db.close()

            val nonCoches = tout.filter { !it.coche }
            val coches = tout.filter { it.coche }.sortedBy { it.nom.lowercase() }

            val resultat = mutableListOf<Ligne>()
            if (tri == "rayon") {
                val groupes = nonCoches.groupBy { it.rayonNom ?: "Sans rayon" }
                val clesTriees = groupes.keys.sortedWith(compareBy(
                    { if (it == "Sans rayon") 1 else 0 },
                    { groupes[it]!!.first().rayonOrdre },
                    { it },
                ))
                for (cle in clesTriees) {
                    resultat.add(Ligne.Entete(cle))
                    for (a in groupes[cle]!!.sortedBy { it.nom.lowercase() }) {
                        resultat.add(Ligne.Article(a.id, a.nom, a.quantite, a.unite, a.coche))
                    }
                }
            } else {
                for (a in nonCoches.sortedBy { it.nom.lowercase() }) {
                    resultat.add(Ligne.Article(a.id, a.nom, a.quantite, a.unite, a.coche))
                }
            }
            if (coches.isNotEmpty()) {
                resultat.add(Ligne.Entete("✓ Déjà dans le panier"))
                for (a in coches) {
                    resultat.add(Ligne.Article(a.id, a.nom, a.quantite, a.unite, a.coche))
                }
            }
            lignes = resultat
        } catch (e: Exception) {
            Log.e(TAG, "onDataSetChanged error: $e")
            lignes = emptyList()
        }
    }

    override fun getViewAt(position: Int): RemoteViews {
        return when (val ligne = lignes.getOrNull(position)) {
            is Ligne.Entete -> RemoteViews(context.packageName, R.layout.widget_rayon_header).apply {
                setTextViewText(R.id.header_nom, ligne.nom)
            }
            is Ligne.Article -> RemoteViews(context.packageName, R.layout.widget_article_item).apply {
                setTextViewText(R.id.item_check, if (ligne.coche) "✓" else "○")
                setTextViewText(R.id.item_nom, ligne.nom)
                setTextViewText(R.id.item_quantite,
                    if (ligne.unite != null) "×${ligne.quantite} ${ligne.unite}"
                    else if (ligne.quantite > 1) "×${ligne.quantite}" else "")
                if (ligne.coche) {
                    setInt(R.id.item_nom, "setPaintFlags",
                        android.graphics.Paint.STRIKE_THRU_TEXT_FLAG or android.graphics.Paint.ANTI_ALIAS_FLAG)
                    setTextColor(R.id.item_nom, 0x66FFFFFF.toInt())
                } else {
                    setInt(R.id.item_nom, "setPaintFlags", android.graphics.Paint.ANTI_ALIAS_FLAG)
                    setTextColor(R.id.item_nom, 0xEEFFFFFF.toInt())
                }
                // Complété par le PendingIntentTemplate posé sur la ListView
                // (voir SmartCartWidget.updateWidget) : chaque ligne fournit
                // juste l'article concerné, le reste (action, id du widget)
                // vient du template.
                val fillIn = Intent().apply {
                    putExtra(SmartCartWidget.EXTRA_ARTICLE_ID, ligne.id)
                }
                setOnClickFillInIntent(R.id.item_row, fillIn)
            }
            else -> RemoteViews(context.packageName, R.layout.widget_article_item)
        }
    }
}
