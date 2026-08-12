allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// -----------------------------------------------------------------
// Force every Android library plugin to compile against compileSdk 36.
// Some transitively-pulled plugins ship with compileSdk = 34 and their
// dependencies require 36 — Gradle's CheckAarMetadata otherwise aborts
// with "requires compile against version 36 or later" (see
// .cursor/rules/gray_part_pitfalls.md §2).
//
// Registered BEFORE `evaluationDependsOn(":app")` so the afterEvaluate
// callback attaches while every subproject is still un-evaluated.
// -----------------------------------------------------------------
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
                }
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
