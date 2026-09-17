import { ArmenusProvider } from "@armenus/sdk-react-native";
import { useState } from "react";
import { SafeAreaView, StyleSheet, Text, View } from "react-native";
import { DishScreen } from "./DishScreen";
import { MenuScreen } from "./MenuScreen";

/**
 * Armenus React Native example.
 *
 * Fully native rendering — SceneKit on iOS, Filament on Android — and AR
 * through the system viewer. No WebView anywhere.
 */

const KEY = process.env.EXPO_PUBLIC_ARMENUS_KEY;
const BASE_URL = process.env.EXPO_PUBLIC_ARMENUS_BASE_URL;

export function App() {
  /* No navigation library, so the example stays about the SDK. */
  const [selectedId, setSelectedId] = useState<string | null>(null);

  if (!KEY || KEY.startsWith("pk_live_replace")) {
    return (
      <SafeAreaView style={styles.screen}>
        <View style={styles.setup}>
          <Text style={styles.setupTitle}>Almost there</Text>
          <Text style={styles.setupBody}>
            Copy .env.example to .env and set EXPO_PUBLIC_ARMENUS_KEY to a
            publishable key from the dashboard.
          </Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <ArmenusProvider
      publishableKey={KEY}
      {...(BASE_URL ? { baseUrl: BASE_URL } : {})}
    >
      <SafeAreaView style={styles.screen}>
        {selectedId ? (
          <DishScreen itemId={selectedId} onBack={() => setSelectedId(null)} />
        ) : (
          <MenuScreen onSelect={setSelectedId} />
        )}
      </SafeAreaView>
    </ArmenusProvider>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: "#faf8f4" },
  setup: { flex: 1, justifyContent: "center", padding: 24, gap: 8 },
  setupTitle: { fontSize: 22, fontWeight: "700", color: "#1c1a17" },
  setupBody: { fontSize: 15, lineHeight: 22, color: "#6b645c" },
});
