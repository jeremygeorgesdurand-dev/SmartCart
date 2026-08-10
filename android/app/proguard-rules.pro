# TensorFlow Lite (paquet tflite_flutter) — R8 échouait à la minification du
# build release : les classes du délégué GPU sont référencées par réflexion et
# ne doivent pas être supprimées ni provoquer d'avertissement bloquant.
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**
