package com.tonnom.smartcart

import android.app.Activity
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.util.Log
import android.view.Gravity
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

// Petite boîte de dialogue native (pas de moteur Flutter) déclenchée par le
// bouton "+" du widget écran d'accueil : ajouter un article ne demande qu'un
// nom, donc pas besoin d'ouvrir toute l'app pour ça. Écrit directement dans
// la base SQLite partagée avec Flutter, et propose les articles du
// catalogue déjà existants pendant la saisie pour éviter les doublons.
class QuickAddActivity : Activity() {
    private lateinit var listeId: String
    private var articleChoisiId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        listeId = intent.getStringExtra("liste_id") ?: ""
        if (listeId.isEmpty()) {
            finish()
            return
        }

        setContentView(R.layout.activity_quick_add)

        val input = findViewById<EditText>(R.id.qa_input)
        val suggestions = findViewById<LinearLayout>(R.id.qa_suggestions)
        val sousTitre = findViewById<TextView>(R.id.qa_sous_titre)
        val btnAnnuler = findViewById<TextView>(R.id.qa_annuler)
        val btnAjouter = findViewById<TextView>(R.id.qa_ajouter)

        sousTitre.text = nomListe(listeId)?.let { "Dans \"$it\"" } ?: ""

        input.requestFocus()
        input.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            override fun onTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            override fun afterTextChanged(s: Editable?) {
                articleChoisiId = null
                afficherSuggestions(s?.toString()?.trim() ?: "", suggestions, input)
            }
        })

        btnAnnuler.setOnClickListener { finish() }
        btnAjouter.setOnClickListener {
            val nom = input.text.toString().trim()
            if (nom.isNotEmpty()) ajouterArticle(nom)
            finish()
        }
    }

    private fun nomListe(listeId: String): String? {
        return try {
            val dbFile = getDatabasePath("smartcart.db")
            if (!dbFile.exists()) return null
            val db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
            val cursor = db.rawQuery("SELECT nom FROM listes WHERE id = ? LIMIT 1", arrayOf(listeId))
            val nom = if (cursor.moveToFirst()) cursor.getString(0) else null
            cursor.close()
            db.close()
            nom
        } catch (e: Exception) {
            null
        }
    }

    private fun afficherSuggestions(query: String, container: LinearLayout, input: EditText) {
        container.removeAllViews()
        if (query.length < 2) {
            container.visibility = LinearLayout.GONE
            return
        }
        try {
            val dbFile = getDatabasePath("smartcart.db")
            if (!dbFile.exists()) return
            val db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
            val cursor = db.rawQuery(
                "SELECT id, nom FROM articles WHERE LOWER(nom) LIKE ? ORDER BY nom LIMIT 5",
                arrayOf("%${query.lowercase(Locale.ROOT)}%"))

            var trouve = false
            while (cursor.moveToNext()) {
                trouve = true
                val articleId = cursor.getString(0)
                val nomArticle = cursor.getString(1)
                val item = TextView(this).apply {
                    text = nomArticle
                    setTextColor(0xFFEEEEEE.toInt())
                    textSize = 14f
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding(10, 22, 10, 22)
                    isClickable = true
                    isFocusable = true
                    setOnClickListener {
                        input.setText(nomArticle)
                        input.setSelection(nomArticle.length)
                        articleChoisiId = articleId
                        container.visibility = LinearLayout.GONE
                    }
                }
                container.addView(item)
            }
            cursor.close()
            db.close()
            container.visibility = if (trouve) LinearLayout.VISIBLE else LinearLayout.GONE
        } catch (e: Exception) {
            Log.e("QuickAddActivity", "afficherSuggestions error: $e")
        }
    }

    private fun ajouterArticle(nom: String) {
        try {
            val dbFile = getDatabasePath("smartcart.db")
            if (!dbFile.exists()) return
            val db = SQLiteDatabase.openDatabase(
                dbFile.path, null, SQLiteDatabase.OPEN_READWRITE)

            var articleId = articleChoisiId
            if (articleId == null) {
                val cursor = db.rawQuery(
                    "SELECT id FROM articles WHERE LOWER(nom) = ? LIMIT 1",
                    arrayOf(nom.lowercase(Locale.ROOT)))
                if (cursor.moveToFirst()) articleId = cursor.getString(0)
                cursor.close()
            }

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

            // Si cet article est déjà dans la liste, augmenter sa quantité
            // plutôt que d'insérer une seconde ligne en double — ça
            // arrivait à chaque fois qu'on retapait un nom déjà présent
            // (suggestion choisie ou correspondance exacte trouvée ci-dessus).
            val existant = db.rawQuery(
                "SELECT id, quantite FROM articles_liste WHERE listeId = ? AND articleId = ? LIMIT 1",
                arrayOf(listeId, articleId))
            if (existant.moveToFirst()) {
                val alId = existant.getString(0)
                val quantiteActuelle = existant.getInt(1)
                existant.close()
                db.execSQL(
                    "UPDATE articles_liste SET quantite = ? WHERE id = ?",
                    arrayOf(quantiteActuelle + 1, alId))
            } else {
                existant.close()
                db.insert("articles_liste", null, ContentValues().apply {
                    put("id", "al_${System.currentTimeMillis()}")
                    put("listeId", listeId)
                    put("articleId", articleId)
                    put("quantite", 1)
                    put("coche", 0)
                })
            }
            db.close()

            SmartCartWidget.regenererCacheDepuisDB(this, listeId)
        } catch (e: Exception) {
            Log.e("QuickAddActivity", "ajouterArticle error: $e")
        }
    }
}
