package com.tonnom.smartcart

import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class WidgetListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return WidgetListFactory(applicationContext)
    }
}

class WidgetListFactory(private val ctx: Context) : RemoteViewsService.RemoteViewsFactory {

    data class ArticleItem(
        val id: String,
        val articleId: String,
        val nom: String,
        val quantite: Int,
        val coche: Boolean,
    )

    private var items = listOf<ArticleItem>()

    override fun onCreate() { load() }
    override fun onDataSetChanged() { load() }
    override fun onDestroy() {}

    private fun findString(prefs: android.content.SharedPreferences, key: String): String? {
        return prefs.getString("flutter.$key", null)
            ?: prefs.getString(key, null)
    }

    private fun load() {
        val prefs = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val json = findString(prefs, "widget_articles_json")
        Log.d("WidgetFactory", "load() json=${json?.take(60) ?: "NULL"}")

        if (json == null) { items = emptyList(); return }

        try {
            val arr = JSONArray(json)
            val list = mutableListOf<ArticleItem>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                list.add(ArticleItem(
                    id = obj.optString("id"),
                    articleId = obj.optString("articleId"),
                    nom = obj.optString("nom"),
                    quantite = obj.optInt("quantite", 1),
                    coche = obj.optBoolean("coche", false),
                ))
            }
            items = list.sortedWith(compareBy({ it.coche }, { it.nom }))
            Log.d("WidgetFactory", "Loaded ${items.size} items OK")
        } catch (e: Exception) {
            Log.e("WidgetFactory", "Parse error: $e")
            items = emptyList()
        }
    }

    override fun getCount(): Int = items.size
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= items.size) {
            return RemoteViews(ctx.packageName, R.layout.widget_article_item)
        }
        val item = items[position]
        val rv = RemoteViews(ctx.packageName, R.layout.widget_article_item)

        rv.setTextViewText(R.id.item_check, if (item.coche) "✓" else "○")
        rv.setTextViewText(R.id.item_nom, item.nom)
        rv.setTextViewText(R.id.item_quantite,
            if (item.quantite > 1) "×${item.quantite}" else "")

        if (item.coche) {
            rv.setInt(R.id.item_nom, "setPaintFlags",
                Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
            rv.setTextColor(R.id.item_nom, 0x66FFFFFF.toInt())
            rv.setTextColor(R.id.item_check, 0x88FFFFFF.toInt())
        } else {
            rv.setInt(R.id.item_nom, "setPaintFlags", Paint.ANTI_ALIAS_FLAG)
            rv.setTextColor(R.id.item_nom, 0xEEFFFFFF.toInt())
            rv.setTextColor(R.id.item_check, 0xCCFFFFFF.toInt())
        }

        val fillIn = Intent().apply {
            putExtra(SmartCartWidget.EXTRA_ARTICLE_ID, item.id)
        }
        rv.setOnClickFillInIntent(R.id.item_check, fillIn)
        rv.setOnClickFillInIntent(R.id.item_nom, fillIn)

        return rv
    }
}
