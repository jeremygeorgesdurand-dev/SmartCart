package com.tonnom.smartcart

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tonnom.smartcart/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Appelé par Flutter après chaque modif, avec les données
                    // du widget en argument (le plugin shared_preferences
                    // utilise Jetpack DataStore depuis la v2.3+, donc le
                    // widget natif ne peut plus lire ce que Flutter écrirait
                    // via SharedPreferences.getInstance() : on reçoit les
                    // données directement et on les écrit nous-mêmes dans le
                    // vrai fichier SharedPreferences que lit SmartCartWidget).
                    "updateWidget" -> {
                        val args = call.arguments as? Map<*, *>
                        if (args != null) {
                            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                            prefs.edit()
                                .putString("widget_liste_id", args["listeId"] as? String ?: "")
                                .putString("widget_liste_nom", args["listeNom"] as? String ?: "")
                                .putInt("widget_total", (args["total"] as? Int) ?: 0)
                                .putInt("widget_coches", (args["coches"] as? Int) ?: 0)
                                .putString("widget_articles_json", args["articlesJson"] as? String ?: "[]")
                                .apply()
                        }
                        refreshAllWidgets()
                        result.success(null)
                    }
                    "clearWidget" -> {
                        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        val editor = prefs.edit()
                        for (key in listOf("widget_liste_id", "widget_liste_nom",
                                "widget_articles_json", "widget_total", "widget_coches")) {
                            editor.remove(key).remove("flutter.$key")
                        }
                        editor.apply()
                        refreshAllWidgets()
                        result.success(null)
                    }
                    // Flutter demande si l'app a été ouverte via le widget
                    "getWidgetIntent" -> {
                        val action = intent?.getStringExtra("action")
                        val listeId = intent?.getStringExtra("open_liste_id")
                            ?: intent?.getStringExtra("liste_id")
                        // La clé posée par SmartCartWidget pour un tap de case
                        // à cocher est "article_liste_id" (l'id de la ligne
                        // articles_liste, pas de l'article catalogue) : lire
                        // "article_id" ici renvoyait toujours vide côté Dart.
                        val articleListeId = intent?.getStringExtra("article_liste_id")
                        result.success(mapOf(
                            "action" to (action ?: ""),
                            "liste_id" to (listeId ?: ""),
                            "article_liste_id" to (articleListeId ?: ""),
                        ))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Notifier Flutter qu'il y a un nouvel intent
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, CHANNEL).invokeMethod("onNewIntent", mapOf(
                "action" to (intent.getStringExtra("action") ?: ""),
                "liste_id" to (intent.getStringExtra("open_liste_id") ?: intent.getStringExtra("liste_id") ?: ""),
                "article_liste_id" to (intent.getStringExtra("article_liste_id") ?: ""),
            ))
        }
    }

    private fun refreshAllWidgets() {
        val manager = AppWidgetManager.getInstance(this)
        val ids = manager.getAppWidgetIds(ComponentName(this, SmartCartWidget::class.java))
        for (id in ids) {
            SmartCartWidget.updateWidget(this, manager, id)
        }
    }
}
