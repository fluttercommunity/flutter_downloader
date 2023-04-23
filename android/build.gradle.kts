buildscript {
    val kotlin_version by extra("1.7.22")

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:7.2.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
    id("org.jlleitschuh.gradle.ktlint") version "11.0.0"
}

group = "vn.hunghd.flutterdownloader"
version = "1.0-SNAPSHOT"

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

android {
    compileSdk = 32

    sourceSets.getByName("main") {
        java.srcDir("src/main/kotlin")
    }

    defaultConfig {
        minSdk = 19
        targetSdk = 32
    }
}

dependencies {
    implementation("androidx.work:work-runtime:2.7.1")
    implementation("androidx.annotation:annotation:1.5.0")
    implementation("androidx.core:core-ktx:1.9.0")
}
