buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2") // Firebase
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Certains plugins (ex. tflite_flutter, speech_to_text) fixent eux-mêmes leur
// compilation Java/Kotlin sur des versions de JVM différentes (1.8, 11, 21…),
// ce qui casse le build ("Inconsistent JVM-target compatibility"). On force
// tous les sous-projets sur la même cible que l'app (17), Java comme Kotlin.
// IMPORTANT : ce bloc est placé AVANT `evaluationDependsOn(":app")` pour que
// nos `afterEvaluate` s'enregistrent tant que les sous-projets ne sont pas
// encore évalués — et s'exécutent donc APRÈS le réglage du plugin, pour le
// remplacer (un plugins.withId trop précoce était au contraire écrasé).
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
