# ML Kit reconnaissance de texte (lecture de ticket de caisse) : on n'utilise
# QUE l'écriture latine. R8 voit des références aux reconnaisseurs optionnels
# (chinois, japonais, coréen, devanagari) qu'on n'embarque pas et échoue sinon
# à la minification. On garde les classes ML Kit référencées par réflexion et
# on ignore les scripts non utilisés.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
