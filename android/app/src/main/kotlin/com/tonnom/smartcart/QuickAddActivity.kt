package com.tonnom.smartcart

import android.app.Activity
import android.app.AlertDialog
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.os.Bundle
import android.text.InputType
import android.util.Log
import android.widget.EditText
import android.widget.FrameLayout
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

// Petite boîte de dialogue native (pas de moteur Flutter) déclenchée par le
// bouton "+" du widget écran d'accueil : ajouter un article ne demande qu'un
// nom, donc pas besoin d'ouvrir toute l'app pour ça. Écrit directement dans
// la base SQLite partagée avec Flutter.
class QuickAddActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val listeId = intent.getStringExtra("liste_id")
        if (listeId.isNullOrEmpty()) {
            finish()
            return
        }

        val padding = (16 * resources.displayMetrics.density).toInt()
        val input = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            hint = "Nom de l'article"
        }
        val container = FrameLayout(this)
        val params = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT)
        params.leftMargin = padding
        params.rightMargin = padding
        container.addView(input, params)

        AlertDialog.Builder(this)
            .setTitle("Ajouter un article")
            .setView(container)
            .setNegativeButton("Annuler") { _, _ -> finish() }
            .setPositiveButton("Ajouter") { _, _ ->
                val nom = input.text.toString().trim()
                if (nom.isNotEmpty()) ajouterArticle(listeId, nom)
                finish()
            }
            .setOnCancelListener { finish() }
            .setOnDismissListener { finish() }
            .show()
    }

    private fun ajouterArticle(listeId: String, nom: String) {
        try {
            val dbFile = getDatabasePath("smartcart.db")
            if (!dbFile.exists()) return
            val db = SQLiteDatabase.openDatabase(
                dbFile.path, null, SQLiteDatabase.OPEN_READWRITE)

            var articleId: String? = null
            val cursor = db.rawQuery(
                "SELECT id FROM articles WHERE LOWER(nom) = ? LIMIT 1",
                arrayOf(nom.lowercase(Locale.ROOT)))
            if (cursor.moveToFirst()) articleId = cursor.getString(0)
            cursor.close()

            if (articleId == null) {
                articleId = "article_${System.currentTimeMillis()}"
                val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.ROOT).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }.format(java.util.Date())
                db.insert("articles", null, ContentValues().apply {
                    put("id", articleId)
                    put("nom", nom)
                    put("createdAt", iso)
                })
            }

            db.insert("articles_liste", null, ContentValues().apply {
                put("id", "al_${System.currentTimeMillis()}")
                put("listeId", listeId)
                put("articleId", articleId)
                put("quantite", 1)
                put("coche", 0)
            })
            db.close()

            SmartCartWidget.regenererCacheDepuisDB(this, listeId)
        } catch (e: Exception) {
            Log.e("QuickAddActivity", "ajouterArticle error: $e")
        }
    }
}
