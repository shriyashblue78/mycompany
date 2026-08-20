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

subprojects {
    val p = this
    val configureAndroid = {
        if (p.plugins.hasPlugin("com.android.application") ||
            p.plugins.hasPlugin("com.android.library")) {
            p.extensions.configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(36)
                println("Forcing compileSdkVersion=36 on subproject: ${p.name}")
            }
        }
    }
    if (p.state.executed) {
        configureAndroid()
    } else {
        p.afterEvaluate {
            configureAndroid()
        }
    }
}



tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

