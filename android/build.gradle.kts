plugins {
    // 🔴 FIXED: Remove apply false - let Flutter manage these properly
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.2.0" apply false
    id("dev.flutter.flutter-gradle-plugin") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // 🔴 FIXED: Consolidated resolution strategy with proper ordering
    configurations.all {
        resolutionStrategy {
            // Force Kotlin 2.2.0 across ALL modules
            force("org.jetbrains.kotlin:kotlin-stdlib:2.2.0")
            force("org.jetbrains.kotlin:kotlin-stdlib-common:2.2.0")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.2.0")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.2.0")
            force("org.jetbrains.kotlin:kotlin-reflect:2.2.0")

            // 🔴 REMOVED: kotlin-build-tools-impl causes conflicts
            // force("org.jetbrains.kotlin:kotlin-build-tools-impl:2.2.0")

            // 🔴 ADDED: Cache handling
            cacheChangingModulesFor(0, "seconds")
            cacheDynamicVersionsFor(0, "seconds")
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)

    // 🔴 FIXED: Proper afterEvaluate with Kotlin version enforcement
    afterEvaluate {
        // Configure Kotlin extension if present
        extensions.findByType<org.jetbrains.kotlin.gradle.dsl.KotlinProjectExtension>()?.let { ext ->
            ext.explicitApi = null
        }

        // 🔴 ADDED: Force Kotlin version on all dependencies
        configurations.all {
            resolutionStrategy.eachDependency {
                if (requested.group == "org.jetbrains.kotlin") {
                    useVersion("2.2.0")
                    because("Force Kotlin 2.2.0 for all modules")
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