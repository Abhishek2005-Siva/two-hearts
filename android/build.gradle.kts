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

// Force every plugin module onto the same JVM 17 target as :app
// (build.gradle.kts above). Older/unmaintained plugins (e.g.
// receive_sharing_intent) ship their own build.gradle with no explicit
// Java/Kotlin compatibility set, so they inherit whatever default the
// resolved AGP/Kotlin Gradle Plugin versions happen to pick — which can
// land Java compilation on 1.8 and Kotlin compilation on 17, and Gradle
// refuses to build with "Inconsistent JVM Target Compatibility Between
// Java and Kotlin Tasks". Rather than patching each plugin (impossible —
// their build.gradle lives in the pub cache, not this repo, and a fresh
// `flutter pub get` would just re-fetch the unpatched version), pin
// every subproject to the same target here.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
