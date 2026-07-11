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

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// file_picker 11.x ships Kotlin sources but deliberately skips applying the
// Kotlin Gradle Plugin on AGP 9 (its build.gradle guards with `isAgp9OrAbove`),
// so its `FilePickerPlugin.kt` is never compiled and the app fails with
// "cannot find symbol class FilePickerPlugin". Force Built-in Kotlin onto the
// plugin module so it compiles and the symbol resolves.
subprojects {
    afterEvaluate {
        if (name == "file_picker" && !plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            plugins.apply("org.jetbrains.kotlin.android")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
