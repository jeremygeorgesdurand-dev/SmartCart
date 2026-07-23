package com.tonnom.smartcart

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

class SmartCartWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_COCHER = "com.tonnom.smartcart.ACTION_COCHER"
        const val ACTION_TRI = "com.tonnom.smartcart.ACTION_TRI"
        const val EXTRA_ARTICLE_ID = "article_id"
        const val EXTRA_WIDGET_ID = "widget_id"
        private const val TAG = "SmartCartWidget"

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
            val progression = if (total > 0) (cochesCount * 100 / total) else 0

            Log.d(TAG, "update: nom=$listeNom total=$total")

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

            // Tap ⇅ = bascule tri alphabétique / par rayon, sans ouvrir l'app
            // (même schéma que ACTION_COCHER : un broadcast traité par
            // onReceive plus bas, qui relit juste la préférence et rafraîchit
            // l'adaptateur de la liste).
            val iTri = Intent(context, SmartCartWidget::class.java).apply {
                action = ACTION_TRI
                putExtra(EXTRA_WIDGET_ID, widgetId)
                putExtra("liste_id", listeId ?: "")
            }
            views.setOnClickPendingIntent(R.id.widget_btn_tri,
                PendingIntent.getBroadcast(context, widgetId * 10 + 2, iTri,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

            // ── Articles : liste défilable via RemoteViewsService ────
            // Remplace l'ancien rendu à 6 lignes fixes (le reste de la liste
            // était invisible, sans aucun moyen de défiler) par une vraie
            // ListView adossée à un adaptateur qui relit la base à chaque
            // notifyAppWidgetViewDataChanged().
            val serviceIntent = Intent(context, SmartCartWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                putExtra("liste_id", listeId ?: "")
                // L'URI doit être unique par widget ET changer quand la
                // liste choisie change : Android compare les intents via
                // Intent.filterEquals (action/data/type/composant), qui
                // IGNORE les extras. Avec une URI ne contenant que le
                // widgetId, changer de liste dans Paramètres → Widget
                // laissait le système réutiliser l'ancienne factory déjà
                // connectée (avec l'ancien listeId figé dedans) au lieu
                // d'en recréer une neuve — la liste défilante restait donc
                // bloquée sur les articles de l'ancienne liste, alors que
                // l'en-tête/compteur (basés sur les préférences, pas cette
                // factory) se mettaient à jour correctement.
                data = android.net.Uri.parse("smartcart://widget/$widgetId/${listeId ?: ""}")
            }
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)
            views.setTextViewText(R.id.widget_empty,
                when {
                    listeId == null -> "Configurez dans\nParamètres → Widget"
                    else -> "Liste vide\nAppuyez sur + pour ajouter"
                })

            // Un seul PendingIntent "template" pour toute la liste : chaque
            // ligne fournit juste l'id de l'article concerné via
            // setOnClickFillInIntent (voir SmartCartWidgetService), le
            // système les fusionne à l'appui. FLAG_MUTABLE est nécessaire
            // ici (Android 12+) pour que cette fusion soit autorisée.
            val iCocher = Intent(context, SmartCartWidget::class.java).apply {
                action = ACTION_COCHER
                putExtra(EXTRA_WIDGET_ID, widgetId)
                putExtra("liste_id", listeId ?: "")
            }
            views.setPendingIntentTemplate(R.id.widget_list,
                PendingIntent.getBroadcast(context, widgetId * 10 + 1, iCocher,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE))

            manager.updateAppWidget(widgetId, views)
            manager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
            Log.d(TAG, "Widget updated OK - liste=$listeId")
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
        } else if (intent.action == ACTION_TRI) {
            val widgetId = intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE)
            val triActuel = (prefs.all["widget_tri"] as? String) ?: "alpha"
            val nouveauTri = if (triActuel == "rayon") "alpha" else "rayon"
            prefs.edit().putString("widget_tri", nouveauTri).apply()
            Log.d(TAG, "Tri basculé -> $nouveauTri")

            // Le tri est commun à tous les widgets (une seule préférence) :
            // rafraîchir chaque instance, pas seulement celle tapée.
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, SmartCartWidget::class.java))
            for (id in ids) updateWidget(context, manager, id)
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
