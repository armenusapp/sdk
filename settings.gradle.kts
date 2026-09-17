pluginManagement {
  repositories {
    google()
    mavenCentral()
    gradlePluginPortal()
  }
}

dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
  repositories {
    google()
    mavenCentral()
  }
}

rootProject.name = "armenus-sdk-android"

// The library module lives in `android/` so the same layout works in the
// Armenus monorepo and at the root of the public SDK repository, where JitPack
// resolves it as `com.github.armenusapp:sdk:<tag>`.
include(":armenus")
project(":armenus").projectDir = file("android")
