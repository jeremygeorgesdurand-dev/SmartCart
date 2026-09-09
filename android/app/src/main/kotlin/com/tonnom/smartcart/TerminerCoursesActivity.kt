package com.tonnom.smartcart

import android.app.Activity
import android.database.sqlite.SQLiteDatabase
import android.os.Bundle
import android.util.Log
import android.widget.TextView

// Confirmation « ✓ Terminer » du widget : retire de la liste les articles
// COCHÉS (achetés), garde les non cochés pour la prochaine fois — même
// comportement que « Terminer les courses » dans l'app. Écrit directement
// dans la base SQLite partagée et note les suppressions dans une file
// d'attente (sync_suppr_widget) pour que l'app les répercute vers Firestore
// à sa prochaine ouverture (le natif ne peut pas écrire au cloud).
//
// Carte stylée (activity_terminer_courses.xml, même habillage que
// QuickAddActivity) plutôt qu'un AlertDialog générique Android : celui-ci
// prenait l'apparence brute du thème système (souvent un popup gris terne),
// qui jurait avec le reste de l'app.
class TerminerCoursesActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val listeId = intent.getStringExtra("liste_id") ?: ""
        if (listeId.isEmpty()) {
            finish()
            return
        }

        setContentView(R.layout.activity_terminer_courses)

        val titre = findViewById<TextView>(R.id.tc_titre)
        val message = findViewById<TextView>(R.id.tc_message)
        val icone = findViewById<TextView>(R.id.tc_icone)
        val btnAnnuler = findViewById<TextView>(R.id.tc_annuler)
        val btnValider = findViewById<TextView>(R.id.tc_valider)

        val coches = compterCoches(listeId)
        if (coches == 0) {
            icone.text = "🛒"
            titre.text = "Rien à terminer"
            message.text = "Aucun article coché pour l'instant."
            btnAnnuler.visibility = android.view.View.GONE
            btnValider.text = "OK"
            btnValider.setOnClickListener { finish() }
            return
        }

        message.text = "Retirer les $coches article(s) coché(s) de la liste ?\n" +
            "Les articles non cochés sont gardés."
        btnAnnuler.setOnClickListener { finish() }
        btnValider.setOnClickListener {
            terminer(listeId)
            finish()
        }
    }

    override fun onBackPressed() {
        finish()
    }

    private fun compterCoches(listeId: String): Int {
        return try {
            val dbFile = getDatabasePath("smartcart.db")
            if (!dbFile.exists()) return 0
            val db = SQLiteDatabase.openDatabase(
                dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
            val c = db.rawQuery(
                "SELECT COUNT(*) FROM articles_liste WHERE listeId = ? AND coche = 1",
                arrayOf(listeId))
            val n = if (c.moveToFirst()) c.getInt(0) else 0
            c.close()
            db.close()
            n
        } catch (e: Exception) {
            Log.e("TerminerCourses", "compterCoches: $e")
            0
        }
    }

    private fun terminer(listeId: String) {
        try {
            val dbFile = getDatabasePath("smartcart.db")
            if (!dbFile.exists()) return
            val db = SQLiteDatabase.openDatabase(
                dbFile.path, null, SQLiteDatabase.OPEN_READWRITE)
            // Récupère les ids cochés, les met en file de suppression, puis les
            // retire localement.
            val c = db.rawQuery(
                "SELECT id FROM articles_liste WHERE listeId = ? AND coche = 1",
                arrayOf(listeId))
            val ids = mutableListOf<String>()
            while (c.moveToNext()) ids.add(c.getString(0))
            c.close()
            for (id in ids) {
                try {
                    db.execSQL(
                        "INSERT OR REPLACE INTO sync_suppr_widget (id, listeId) VALUES (?, ?)",
                        arrayOf(id, listeId))
                } catch (e: Exception) {
                    Log.e("TerminerCourses", "file suppr: $e")
                }
                db.execSQL("DELETE FROM articles_liste WHERE id = ?", arrayOf(id))
            }
            db.close()
            // Rafraîchit le widget (compteur + liste).
            SmartCartWidget.regenererCacheDepuisDB(this, listeId)
        } catch (e: Exception) {
            Log.e("TerminerCourses", "terminer: $e")
        }
    }
}
