package com.tonnom.smartcart

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray

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

        private fun findString(prefs: android.content.SharedPreferences, key: String): String? =
            prefs.getString("flutter.$key", null) ?: prefs.getString(key, null)

        private fun findInt(prefs: android.content.SharedPreferences, key: String): Int {
            if (prefs.contains("flutter.$key")) return prefs.getInt("flutter.$key", 0)
            return prefs.getInt(key, 0)
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

            // Tap + = ouvrir ajout
            val iAdd = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                if (listeId != null) putExtra("open_liste_id", listeId)
                putExtra("action", "add_article")
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
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        Log.d(TAG, "onUpdate ${ids.size} widgets")
        for (id in ids) updateWidget(context, manager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_COCHER) {
            val articleListeId = intent.getStringExtra(EXTRA_ARTICLE_ID) ?: return
            val listeId = intent.getStringExtra("liste_id") ?: ""
            Log.d(TAG, "Cocher: $articleListeId in $listeId")

            val i = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("action", "cocher_article")
                putExtra("article_liste_id", articleListeId)
                putExtra("liste_id", listeId)
            }
            context.startActivity(i)
        }
    }
}
