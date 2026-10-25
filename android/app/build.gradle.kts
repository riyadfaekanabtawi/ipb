plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
}

android {
    namespace = "com.nevutech.trama"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.nevutech.trama"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // Trama platform API (platform/). Debug builds can override it with the `apiBase` intent extra.
        buildConfigField("String", "API_BASE", "\"https://trama-platform.vercel.app/api\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    testOptions { unitTests.isIncludeAndroidResources = true }
    // The language can be switched in the app, so every language must ship in the base APK.
    bundle { language { enableSplit = false } }
}

/**
 * Brazilian Portuguese is the only Portuguese we write; this copies values-pt-rBR to values-pt
 * at build time so every Portuguese locale (pt-PT, pt-AO, …) gets it instead of Spanish.
 */
abstract class PortugueseFallbackTask : DefaultTask() {
    @get:InputDirectory abstract val source: DirectoryProperty
    @get:OutputDirectory abstract val outputDir: DirectoryProperty

    @TaskAction fun copy() {
        val target = outputDir.get().dir("values-pt").asFile
        target.deleteRecursively()
        target.mkdirs()
        source.get().asFile.listFiles { f -> f.extension == "xml" }?.forEach { it.copyTo(target.resolve(it.name)) }
    }
}

val portugueseFallback = tasks.register<PortugueseFallbackTask>("portugueseFallbackRes") {
    source.set(layout.projectDirectory.dir("src/main/res/values-pt-rBR"))
    outputDir.set(layout.buildDirectory.dir("generated/res/ptFallback"))
}

androidComponents {
    onVariants { variant -> variant.sources.res?.addGeneratedSourceDirectory(portugueseFallback, PortugueseFallbackTask::outputDir) }
}

ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.material3.windowsize)
    implementation(libs.compose.material.icons)
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)
    implementation(libs.datastore.preferences)
    implementation(libs.coil.compose)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.work.runtime)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)

    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.room.testing)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)
}
