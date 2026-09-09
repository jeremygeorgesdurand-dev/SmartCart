package com.tonnom.smartcart

import android.app.Activity
import android.app.AlertDialog
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.os.Bundle
import android.util.Log

// Petite confirmation native (pas de moteur Flutter) déclenchée par le bouton
// « ✓ Terminer » du widget : retire de la liste les articles COCHÉS (achetés),
// garde les non cochés pour la prochaine fois — même comportement que « Terminer
// les courses » dans l'app. Écrit directement dans la base SQLite partagée et
// note les suppressions dans une file d'attente (sync_suppr_widget) pour que
// l'app les répercute vers Firestore à sa prochaine ouverture (le natif ne peut
// pas écrire au cloud). Une confirmation évite les suppressions accidentelles.
class TerminerCoursesActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val listeId = intent.getStringExtra("liste_id") ?: ""
        if (listeId.isEmpty()) {
            finish()
            return
        }

        val coches = compterCoches(listeId)
        if (coches == 0) {
            AlertDialog.Builder(this)
                .setTitle("Terminer les courses")
                .setMessage("Aucun article coché pour l'instant.")
                .setPositiveButton("OK") { _, _ -> finish() }
                .setOnCancelListener { finish() }
                .show()
            return
        }

        AlertDialog.Builder(this)
            .setTitle("Terminer les courses")
            .setMessage("Retirer les $coches article(s) coché(s) de la liste ? " +
                "Les articles non cochés sont gardés.")
            .setNegativeButton("Annuler") { _, _ -> finish() }
            .setPositiveButton("Terminer") { _, _ ->
                terminer(listeId)
                finish()
            }
            .setOnCancelListener { finish() }
            .show()
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
