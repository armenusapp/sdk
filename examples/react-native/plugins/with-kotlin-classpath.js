const { withProjectBuildGradle } = require('@expo/config-plugins');

// Expo 52 sets the Kotlin version property but leaves its Gradle dependency
// unversioned. Pin that dependency too so React Native cannot select Kotlin 1.9.
module.exports = function withKotlinClasspath(config) {
  return withProjectBuildGradle(config, (config) => {
    config.modResults.contents = config.modResults.contents.replace(
      /classpath\(['"]org\.jetbrains\.kotlin:kotlin-gradle-plugin['"]\)/g,
      'classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")',
    );
    return config;
  });
};
