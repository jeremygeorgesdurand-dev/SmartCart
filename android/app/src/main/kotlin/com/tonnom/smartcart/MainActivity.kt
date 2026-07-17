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
                    // Appelé par Flutter après chaque modif pour rafraîchir le widget
                    "updateWidget" -> {
                        refreshAllWidgets()
                        result.success(null)
                    }
                    // Flutter demande si l'app a été ouverte via le widget
                    "getWidgetIntent" -> {
                        val action = intent?.getStringExtra("action")
                        val listeId = intent?.getStringExtra("open_liste_id")
                            ?: intent?.getStringExtra("liste_id")
                        val articleId = intent?.getStringExtra("article_id")
                        result.success(mapOf(
                            "action" to (action ?: ""),
                            "liste_id" to (listeId ?: ""),
                            "article_id" to (articleId ?: ""),
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
                "article_id" to (intent.getStringExtra("article_id") ?: ""),
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
