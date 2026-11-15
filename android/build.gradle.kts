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
    afterEvaluate {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                compileSdk = 36
                // Patch deprecated proguard-android.txt used by older plugin dependencies
                // (e.g. flutter_inappwebview_android). AGP 9.x removed this file; redirect
                // to proguard-android-optimize.txt which is functionally equivalent.
                buildTypes.all {
                    proguardFiles.replaceAll { file ->
                        if (file.name == "proguard-android.txt") {
                            getDefaultProguardFile("proguard-android-optimize.txt")
                        } else {
                            file
                        }
                    }
                }
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
