import {
  ArmenusNative,
  useArmenusConfig,
  useArmenusItems,
  type EmbedItem,
} from "@armenus/sdk-react-native";
import { useCallback, useRef } from "react";
import {
  ActivityIndicator,
  FlatList,
  Image,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  View,
  type ViewToken,
} from "react-native";

const MERCHANT_ID = process.env.EXPO_PUBLIC_ARMENUS_MERCHANT_ID;

export function MenuScreen({
  onSelect,
}: {
  onSelect: (itemId: string) => void;
}) {
  /*
   * config() first. It is the only call that tells a revoked key apart from an
   * empty menu — and a bad key that presents as "this restaurant sells
   * nothing" is the most confusing way for an integration to fail.
   */
  const config = useArmenusConfig();
  const merchantId = MERCHANT_ID ?? config.data?.merchants[0]?.id ?? null;

  const items = useArmenusItems(merchantId, { withModel: true, limit: 30 });

  /*
   * Prefetch the mesh for rows as they become visible.
   *
   * AR Quick Look cannot read a remote URL, so this download has to happen
   * before AR can open at all — only its timing is ours to choose. Doing it
   * here is the difference between an AR button that opens instantly and one
   * that stalls for two seconds on first tap.
   */
  const warmed = useRef(new Set<string>());
  const onViewableItemsChanged = useCallback(
    ({ viewableItems }: { viewableItems: ViewToken[] }) => {
      for (const token of viewableItems) {
        const item = token.item as EmbedItem | undefined;
        const model = item?.model;
        if (!model) continue;

        const url = Platform.OS === "ios" ? model.usdzUrl : model.glbUrl;
        if (!url || warmed.current.has(url)) continue;

        warmed.current.add(url);
        ArmenusNative.prefetch(url).catch(() => {
          // A failed warm-up is not a failure — the AR path downloads on
          // demand anyway. It just will not be instant.
          warmed.current.delete(url);
        });
      }
    },
    [],
  );

  if (config.error) {
    return (
      <Problem
        title="That key did not work"
        detail={config.error.message}
        hint={
          config.error.isAuthError
            ? "Check EXPO_PUBLIC_ARMENUS_KEY."
            : undefined
        }
      />
    );
  }

  if (config.loading || items.loading) {
    return (
      <View style={styles.centre}>
        <ActivityIndicator />
      </View>
    );
  }

  if (items.error) {
    return <Problem title="Could not load dishes" detail={items.error.message} />;
  }

  const dishes = items.data ?? [];

  if (dishes.length === 0) {
    return (
      <Problem
        title="No dishes with models yet"
        detail="This merchant has no dishes with a ready 3D model."
        hint="A normal state, not an error — models are built after upload."
      />
    );
  }

  return (
    <FlatList
      data={dishes}
      keyExtractor={(item) => item.id}
      numColumns={2}
      contentContainerStyle={styles.list}
      columnWrapperStyle={styles.row}
      onViewableItemsChanged={onViewableItemsChanged}
      viewabilityConfig={{ itemVisiblePercentThreshold: 40 }}
      ListHeaderComponent={
        <View style={styles.header}>
          <Text style={styles.eyebrow}>{config.data?.ownerName}</Text>
          <Text style={styles.title}>Menu</Text>
        </View>
      }
      renderItem={({ item }) => (
        <Card item={item} onPress={() => onSelect(item.id)} />
      )}
    />
  );
}

/**
 * A poster, not a 3D view.
 *
 * Mounting a renderer per cell would put twenty GPU surfaces and twenty meshes
 * in a scrolling list to show what a still image already shows. The model
 * belongs on the detail screen, where the user has asked for it.
 */
function Card({ item, onPress }: { item: EmbedItem; onPress: () => void }) {
  const poster = item.model?.posterUrl ?? item.imageUrl;

  return (
    <Pressable style={styles.card} onPress={onPress}>
      <View style={styles.cardMedia}>
        {poster ? (
          <Image source={{ uri: poster }} style={styles.cardImage} />
        ) : null}
      </View>
      <Text style={styles.cardName} numberOfLines={1}>
        {item.name}
      </Text>
      <Text style={styles.cardPrice}>
        {(item.priceCents / 100).toFixed(2)} {item.merchant.currency}
      </Text>
    </Pressable>
  );
}

function Problem({
  title,
  detail,
  hint,
}: {
  title: string;
  detail: string;
  hint?: string;
}) {
  return (
    <View style={styles.problem}>
      <Text style={styles.problemTitle}>{title}</Text>
      <Text style={styles.problemBody}>{detail}</Text>
      {hint ? <Text style={styles.problemHint}>{hint}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  centre: { flex: 1, alignItems: "center", justifyContent: "center" },
  list: { padding: 12, paddingBottom: 48 },
  row: { gap: 12 },
  header: { paddingHorizontal: 4, paddingBottom: 16 },
  eyebrow: {
    fontSize: 12,
    letterSpacing: 1,
    textTransform: "uppercase",
    color: "#6b645c",
  },
  title: { fontSize: 28, fontWeight: "700", color: "#1c1a17" },
  card: {
    flex: 1,
    marginBottom: 12,
    padding: 8,
    borderRadius: 12,
    backgroundColor: "#fff",
    borderWidth: 1,
    borderColor: "#e4dfd5",
  },
  cardMedia: {
    aspectRatio: 1,
    borderRadius: 8,
    overflow: "hidden",
    backgroundColor: "#f0ece4",
  },
  cardImage: { width: "100%", height: "100%" },
  cardName: { marginTop: 8, fontWeight: "600", color: "#1c1a17" },
  cardPrice: { fontSize: 13, color: "#6b645c" },
  problem: { padding: 24, gap: 6 },
  problemTitle: { fontSize: 18, fontWeight: "700", color: "#1c1a17" },
  problemBody: { fontSize: 15, color: "#1c1a17" },
  problemHint: { fontSize: 14, color: "#6b645c" },
});
