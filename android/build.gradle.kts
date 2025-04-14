plugins {
    //id("com.android.application")
}

allprojects {
    repositories {
        google()
        mavenCentral()
                maven { url = uri("https://storage.googleapis.com/download.flutter.io") } // ✅ Add this

    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Required to prevent compileSdkVersion error in root project
plugins.withId("com.android.application") {
    extensions.configure<com.android.build.gradle.AppExtension>("android") {
        compileSdkVersion(33)
    }
}