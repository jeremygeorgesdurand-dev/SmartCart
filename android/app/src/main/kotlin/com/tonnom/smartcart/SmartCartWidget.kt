package com.tonnom.smartcart

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

class SmartCartWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_COCHER = "com.tonnom.smartcart.ACTION_COCHER"
        const val EXTRA_ARTICLE_ID = "article_id"
        const val EXTRA_WIDGET_ID = "widget_id"
        private const val TAG = "SmartCartWidget"
        private const val MAX_ROWS = 6

        private val ROW_IDS = intArrayOf(
            R.id.row_0, R.id.row_1, R.id.row_2,
            R.id.row_3, R.id.row_4, R.id.row_5)
        private val CHECK_IDS = intArrayOf(
            R.id.check_0, R.id.check_1, R.id.check_2,
            R.id.check_3, R.id.check_4, R.id.check_5)
        private val NOM_IDS = intArrayOf(
            R.id.nom_0, R.id.nom_1, R.id.nom_2,
            R.id.nom_3, R.id.nom_4, R.id.nom_5)
        private val QTE_IDS = intArrayOf(
            R.id.qte_0, R.id.qte_1, R.id.qte_2,
            R.id.qte_3, R.id.qte_4, R.id.qte_5)

        data class Article(
            val id: String,
            val nom: String,
            val quantite: Int,
            val coche: Boolean
        )

        // Notre code (MainActivity) écrit toujours la clé "brute" (sans le
        // préfixe "flutter."). Ce préfixe n'existe que pour d'anciennes
        // valeurs laissées par une version antérieure de l'app qui écrivait
        // directement depuis Dart — il faut donc lire la clé brute EN
        // PRIORITÉ : sinon une vieille valeur "flutter.$key" jamais nettoyée
        // est relue indéfiniment et masque toute mise à jour ultérieure
        // (ex: changer la liste choisie dans Paramètres → Widget n'avait
        // alors plus aucun effet visible).
        private fun findString(prefs: android.content.SharedPreferences, key: String): String? {
            val v = prefs.all[key] ?: prefs.all["flutter.$key"]
            return v as? String
        }

        // Le plugin Flutter shared_preferences stocke les int Dart comme des
        // Long en interne (sous la clé "flutter.$key") — une ancienne version
        // de l'app écrivait directement ces clés depuis Dart. getInt() plante
        // avec un ClassCastException si la valeur existante est un Long : on
        // lit donc la valeur brute et on convertit selon son type réel,
        // plutôt que de supposer qu'elle a toujours été écrite par notre
        // propre code (putInt) côté Kotlin.
        private fun findInt(prefs: android.content.SharedPreferences, key: String): Int {
            val v = prefs.all[key] ?: prefs.all["flutter.$key"]
            return when (v) {
                is Int -> v
                is Long -> v.toInt()
                is String -> v.toIntOrNull() ?: 0
                else -> 0
            }
        }

        fun updateWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.smartcart_widget_layout)

            val listeNom = findString(prefs, "widget_liste_nom")
            val listeId = findString(prefs, "widget_liste_id")
            val total = findInt(prefs, "widget_total")
            val cochesCount = findInt(prefs, "widget_coches")
            val articlesJson = findString(prefs, "widget_articles_json")
            val progression = if (total > 0) (cochesCount * 100 / total) else 0

            Log.d(TAG, "update: nom=$listeNom total=$total json=${articlesJson?.length}")

            // ── Header ──────────────────────────────────────────
            views.setTextViewText(R.id.widget_liste_nom, listeNom ?: "SmartCart")
            views.setTextViewText(R.id.widget_compteur,
                if (listeNom != null) "$cochesCount/$total" else "")
            views.setProgressBar(R.id.widget_progress, 100, progression, false)

            // Tap header = ouvrir la liste dans l'app
            val iOpen = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                if (listeId != null) putExtra("open_liste_id", listeId)
            }
            val piOpen = PendingIntent.getActivity(context, 0, iOpen,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_header, piOpen)

            // Tap + = petite boîte de dialogue native pour ajouter un
            // article directement, sans jamais ouvrir l'app (QuickAddActivity
            // est une Activity au thème transparent/dialogue, pas le moteur
            // Flutter : plus rapide et ça ne donne pas l'impression que
            // l'app "s'ouvre").
            val iAdd = Intent(context, QuickAddActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION
                putExtra("liste_id", listeId ?: "")
            }
            views.setOnClickPendingIntent(R.id.widget_btn_add,
                PendingIntent.getActivity(context, 1, iAdd,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

            // ── Articles ─────────────────────────────────────────
            val articles = parseArticles(articlesJson)
            val restants = articles.filter { !it.coche }.sortedBy { it.nom }
            val cochés = articles.filter { it.coche }.sortedBy { it.nom }
            val affichés = (restants + cochés).take(MAX_ROWS)
            val plusCount = articles.size - MAX_ROWS

            if (listeNom != null && articles.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_empty, View.GONE)

                for (i in 0 until MAX_ROWS) {
                    if (i < affichés.size) {
                        val art = affichés[i]
                        views.setViewVisibility(ROW_IDS[i], View.VISIBLE)
                        views.setTextViewText(NOM_IDS[i], art.nom)
                        views.setTextViewText(CHECK_IDS[i], if (art.coche) "✓" else "○")
                        views.setTextViewText(QTE_IDS[i],
                            if (art.quantite > 1) "×${art.quantite}" else "")

                        if (art.coche) {
                            views.setInt(NOM_IDS[i], "setPaintFlags",
                                Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
                            views.setTextColor(NOM_IDS[i], 0x66FFFFFF.toInt())
                        } else {
                            views.setInt(NOM_IDS[i], "setPaintFlags", Paint.ANTI_ALIAS_FLAG)
                            views.setTextColor(NOM_IDS[i], 0xEEFFFFFF.toInt())
                        }

                        // Tap = cocher l'article
                        val iCocher = Intent(context, SmartCartWidget::class.java).apply {
                            action = ACTION_COCHER
                            putExtra(EXTRA_ARTICLE_ID, art.id)
                            putExtra(EXTRA_WIDGET_ID, widgetId)
                            putExtra("liste_id", listeId ?: "")
                        }
                        views.setOnClickPendingIntent(ROW_IDS[i],
                            PendingIntent.getBroadcast(context, i + 100, iCocher,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
                    } else {
                        views.setViewVisibility(ROW_IDS[i], View.GONE)
                    }
                }

                if (plusCount > 0) {
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    views.setTextViewText(R.id.widget_empty,
                        "↓ $plusCount autres — appuyez pour voir tout")
                }

            } else if (listeNom != null) {
                for (i in 0 until MAX_ROWS) views.setViewVisibility(ROW_IDS[i], View.GONE)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty, "Liste vide\nAppuyez sur + pour ajouter")
            } else {
                for (i in 0 until MAX_ROWS) views.setViewVisibility(ROW_IDS[i], View.GONE)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty,
                    "Configurez dans\nParamètres → Widget")
            }

            manager.updateAppWidget(widgetId, views)
            Log.d(TAG, "Widget updated OK - ${affichés.size} articles affichés")
        }

        private fun parseArticles(json: String?): List<Article> {
            if (json == null) return emptyList()
            return try {
                val arr = JSONArray(json)
                (0 until arr.length()).map { i ->
                    val obj = arr.getJSONObject(i)
                    Article(
                        id = obj.optString("id"),
                        nom = obj.optString("nom", "?"),
                        quantite = obj.optInt("quantite", 1),
                        coche = obj.optBoolean("coche", false),
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "JSON error: $e")
                emptyList()
            }
        }

        // Reconstruit entièrement le cache du widget (articles + compteurs)
        // depuis la base SQLite pour une liste donnée, et redessine le
        // widget. Appelé après un ajout d'article fait directement en base
        // par QuickAddActivity (sans passer par l'app Flutter).
        fun regenererCacheDepuisDB(context: Context, listeId: String) {
            try {
                val dbFile = context.getDatabasePath("smartcart.db")
                if (!dbFile.exists()) return
                val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                    dbFile.path, null, android.database.sqlite.SQLiteDatabase.OPEN_READONLY)
                val cursor = db.rawQuery(
                    "SELECT al.id, al.quantite, al.coche, a.nom " +
                        "FROM articles_liste al JOIN articles a ON a.id = al.articleId " +
                        "WHERE al.listeId = ?",
                    arrayOf(listeId))

                val arr = JSONArray()
                var coches = 0
                while (cursor.moveToNext()) {
                    val coche = cursor.getInt(2) == 1
                    arr.put(JSONObject().apply {
                        put("id", cursor.getString(0))
                        put("quantite", cursor.getInt(1))
                        put("coche", coche)
                        put("nom", cursor.getString(3))
                    })
                    if (coche) coches++
                }
                cursor.close()
                db.close()

                val prefs = context.getSharedPreferences(
                    "FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("widget_articles_json", arr.toString())
                    .putInt("widget_total", arr.length())
                    .putInt("widget_coches", coches)
                    .apply()

                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(
                    ComponentName(context, SmartCartWidget::class.java))
                for (id in ids) updateWidget(context, manager, id)
            } catch (e: Exception) {
                Log.e(TAG, "regenererCacheDepuisDB error: $e")
            }
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        Log.d(TAG, "onUpdate ${ids.size} widgets")
        for (id in ids) updateWidget(context, manager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_COCHER) {
            val articleListeId = intent.getStringExtra(EXTRA_ARTICLE_ID) ?: return
            Log.d(TAG, "Cocher: $articleListeId")

            // Coché directement (base SQLite + cache du widget), sans jamais
            // lancer l'app : PendingIntent.getBroadcast permet de répondre à
            // un tap sans ouvrir d'Activity, mais le code précédent lançait
            // quand même MainActivity juste pour faire le "vrai" traitement
            // Flutter — d'où le flash d'ouverture/fermeture à chaque tap. La
            // synchro cloud de ce changement se fera à la prochaine ouverture
            // normale de l'app (l'état local fait foi entre-temps).
            cocherEnBase(context, articleListeId)
            toggleCocheOptimiste(context, articleListeId)
        }
    }

    private fun cocherEnBase(context: Context, articleListeId: String) {
        try {
            val dbFile = context.getDatabasePath("smartcart.db")
            if (!dbFile.exists()) return
            val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                dbFile.path, null, android.database.sqlite.SQLiteDatabase.OPEN_READWRITE)
            db.execSQL(
                "UPDATE articles_liste SET coche = CASE coche WHEN 1 THEN 0 ELSE 1 END WHERE id = ?",
                arrayOf(articleListeId))
            db.close()
        } catch (e: Exception) {
            Log.e(TAG, "cocherEnBase error: $e")
        }
    }

    private fun toggleCocheOptimiste(context: Context, articleListeId: String) {
        try {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE)
            val json = findString(prefs, "widget_articles_json") ?: return

            val arr = JSONArray(json)
            var modifie = false
            var coches = 0
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optString("id") == articleListeId) {
                    obj.put("coche", !obj.optBoolean("coche", false))
                    modifie = true
                }
                if (obj.optBoolean("coche", false)) coches++
            }
            if (!modifie) return

            // Toujours en clé brute : nos propres lectures/écritures ne
            // passent plus par le préfixe "flutter." (voir findString/findInt).
            prefs.edit()
                .putString("widget_articles_json", arr.toString())
                .putInt("widget_coches", coches)
                .apply()

            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, SmartCartWidget::class.java))
            for (id in ids) updateWidget(context, manager, id)
        } catch (e: Exception) {
            Log.e(TAG, "toggleCocheOptimiste error: $e")
        }
    }
}
