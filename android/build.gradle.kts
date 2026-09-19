plugins {
  id("com.android.library")
  id("org.jetbrains.kotlin.android")
  id("maven-publish")
}

group = "app.armenus"
version = "0.1.0"

android {
  namespace = "app.armenus.sdk"
  compileSdk = 36

  defaultConfig {
    // Scene Viewer and ARCore both require 24.
    minSdk = 24
    consumerProguardFiles("consumer-rules.pro")
  }

  buildFeatures {
    buildConfig = false
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  publishing {
    singleVariant("release") {
      withSourcesJar()
    }
  }

  testOptions {
    unitTests.isReturnDefaultValues = true
  }
}

kotlin {
  jvmToolchain(17)
}

dependencies {
  /*
   * SceneView wraps Google's Filament, the renderer behind Scene Viewer and
   * Google Maps. Chosen over raw Filament because it already handles GLB
   * loading, the render-thread lifecycle, IBL setup and surface teardown.
   *
   * Not here on purpose: the ARCore SDK. Placement goes through Scene Viewer,
   * a separate system app, so this library never links ARCore and never adds
   * the camera permission to a host app's manifest.
   */
  api("io.github.sceneview:sceneview:2.3.0")
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")

  testImplementation("junit:junit:4.13.2")
  testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.10.2")
  // The real org.json, because the android.jar stubs on the unit-test
  // classpath throw on every call.
  testImplementation("org.json:json:20250517")
}

publishing {
  publications {
    register<MavenPublication>("release") {
      groupId = "app.armenus"
      artifactId = "armenus"
      version = project.version.toString()
      afterEvaluate {
        from(components["release"])
      }
      pom {
        name.set("Armenus Android SDK")
        description.set("Render restaurant dishes in 3D and place them on a table in AR. Filament inline, Scene Viewer for AR.")
        url.set("https://developers.armenus.app")
        licenses {
          license {
            name.set("MIT")
            url.set("https://opensource.org/licenses/MIT")
          }
        }
        scm {
          url.set("https://github.com/armenusapp/sdk")
        }
      }
    }
  }
}
