import {
  ArmenusModel,
  useArmenusItem,
} from "@armenus/sdk-react-native";
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";

export function DishScreen({
  itemId,
  onBack,
}: {
  itemId: string;
  onBack: () => void;
}) {
  const { data, loading, error } = useArmenusItem(itemId);

  return (
    <ScrollView contentContainerStyle={styles.page}>
      <Pressable style={styles.back} onPress={onBack}>
        <Text style={styles.backText}>← Menu</Text>
      </Pressable>

      {loading ? <ActivityIndicator style={styles.spinner} /> : null}
      {error ? <Text style={styles.error}>{error.message}</Text> : null}

      {/*
        `data` is null while loading and ArmenusModel handles that itself,
        showing the poster until the mesh arrives — so there is no need to
        gate the component behind the loading flag.

        `interactionEnabled` is left on here because this is a full screen,
        not a list cell. In the list it must be false or the model's drag
        handling fights the FlatList for every vertical gesture.
      */}
      <ArmenusModel
        item={data}
        arLabel="See it on your table"
        onEnterAr={(item) => {
          // Your analytics. Fires on activation, not when the button appears.
          console.info("AR opened", item.id);
        }}
        onError={(message) => console.warn("Armenus:", message)}
        footer={(presentation) =>
          /*
           * The only unsupported case worth a hopeful message: the USDZ is
           * still being produced and will exist shortly. Everything else is
           * permanent for this session, and the SDK already renders its own
           * explanation just above this footer.
           */
          presentation.ar.blockedOnConversion ? (
            <Text style={styles.note}>
              The AR version is still being prepared — usually a minute or two.
            </Text>
          ) : null
        }
      />

      {data ? (
        <View style={styles.body}>
          <View style={styles.headRow}>
            <Text style={styles.name}>{data.name}</Text>
            <Text style={styles.price}>
              {(data.priceCents / 100).toFixed(2)} {data.merchant.currency}
            </Text>
          </View>

          {data.description ? (
            <Text style={styles.description}>{data.description}</Text>
          ) : null}

          {data.model ? (
            <Text style={styles.meta}>
              Shown at actual size — {Math.round(data.model.physicalSizeM * 100)}{" "}
              cm across.
            </Text>
          ) : (
            <Text style={styles.meta}>
              This dish does not have a 3D model yet.
            </Text>
          )}
        </View>
      ) : null}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  page: { padding: 16, paddingBottom: 64 },
  back: { alignSelf: "flex-start", paddingVertical: 8, paddingRight: 12 },
  backText: { fontSize: 15, color: "#6b645c" },
  spinner: { marginVertical: 24 },
  error: { color: "#c0392b", marginBottom: 12 },
  note: {
    marginTop: 8,
    fontSize: 13,
    color: "#6b645c",
    textAlign: "center",
  },
  body: { marginTop: 20, gap: 10 },
  headRow: {
    flexDirection: "row",
    alignItems: "baseline",
    justifyContent: "space-between",
    gap: 12,
  },
  name: { flex: 1, fontSize: 22, fontWeight: "700", color: "#1c1a17" },
  price: { fontSize: 17, color: "#1c1a17" },
  description: { fontSize: 15, lineHeight: 22, color: "#4a453f" },
  meta: { fontSize: 13, color: "#6b645c" },
});
