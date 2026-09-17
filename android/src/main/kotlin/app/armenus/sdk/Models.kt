package app.armenus.sdk

import org.json.JSONArray
import org.json.JSONObject

/*
 * The wire shape of the embed API, field for field the same as the TypeScript
 * and Swift SDKs. Parsed with the platform's own org.json so the library adds
 * no serialization dependency to a host app.
 */

/** USDZ readiness. Only iOS depends on it, but it is reported everywhere. */
enum class UsdzStatus(val wire: String) {
  PENDING("pending"),
  PROCESSING("processing"),
  READY("ready"),
  FAILED("failed");

  companion object {
    fun fromWire(value: String?): UsdzStatus =
      entries.firstOrNull { it.wire == value } ?: PENDING
  }
}

/** Camera framing, passed through to whichever renderer the platform uses. */
data class ModelViewSettings(
  /** `"theta phi radius"`, e.g. `"0deg 75deg 105%"`, in model-viewer's format. */
  val cameraOrbit: String,
  val cameraTarget: String,
  val fieldOfView: String,
  val exposure: Double,
  val shadowIntensity: Double,
  val autoRotate: Boolean,
  /**
   * Multiplier applied before AR placement, on top of [EmbedModel.physicalSizeM].
   * The size is a measurement; this is a correction a restaurant applies when
   * the placed result still reads wrong.
   */
  val arScale: Double,
) {
  companion object {
    fun fromJson(json: JSONObject) = ModelViewSettings(
      cameraOrbit = json.optString("cameraOrbit", "0deg 75deg 105%"),
      cameraTarget = json.optString("cameraTarget", "auto auto auto"),
      fieldOfView = json.optString("fieldOfView", "auto"),
      exposure = json.optDouble("exposure", 1.0),
      shadowIntensity = json.optDouble("shadowIntensity", 1.0),
      autoRotate = json.optBoolean("autoRotate", true),
      arScale = json.optDouble("arScale", 1.0),
    )
  }
}

data class EmbedModel(
  val id: String,
  /** Android inline (Filament), Scene Viewer AR, and every browser path. */
  val glbUrl: String,
  /** iOS only. Null until conversion finishes. */
  val usdzUrl: String?,
  val usdzStatus: UsdzStatus,
  /** Shown while the mesh downloads, and wherever no mesh can be rendered. */
  val posterUrl: String?,
  /** Longest side in metres. Required for AR placement at believable scale. */
  val physicalSizeM: Double,
  /** Optimised GLB size. Null on rows predating the measurement. */
  val glbBytes: Long?,
  val viewSettings: ModelViewSettings,
) {
  companion object {
    fun fromJson(json: JSONObject) = EmbedModel(
      id = json.getString("id"),
      glbUrl = json.getString("glbUrl"),
      usdzUrl = json.optStringOrNull("usdzUrl"),
      usdzStatus = UsdzStatus.fromWire(json.optStringOrNull("usdzStatus")),
      posterUrl = json.optStringOrNull("posterUrl"),
      physicalSizeM = json.optDouble("physicalSizeM", 0.0),
      glbBytes = if (json.isNull("glbBytes")) null else json.optLong("glbBytes"),
      viewSettings = ModelViewSettings.fromJson(json.optJSONObject("viewSettings") ?: JSONObject()),
    )
  }
}

data class EmbedMerchant(
  val id: String,
  val slug: String,
  val name: String,
  val currency: String,
  val locale: String,
) {
  companion object {
    fun fromJson(json: JSONObject) = EmbedMerchant(
      id = json.getString("id"),
      slug = json.getString("slug"),
      name = json.getString("name"),
      currency = json.optString("currency", "USD"),
      locale = json.optString("locale", "en-US"),
    )
  }
}

data class EmbedItem(
  val id: String,
  val slug: String,
  /** The host app's own identifier, when it set one. */
  val externalRef: String?,
  val name: String,
  val description: String?,
  val priceCents: Int,
  val tags: List<String>,
  val imageUrl: String?,
  val isAvailable: Boolean,
  val merchant: EmbedMerchant,
  /** Null when the dish has no model, or has one that is not ready yet. */
  val model: EmbedModel?,
) {
  companion object {
    fun fromJson(json: JSONObject) = EmbedItem(
      id = json.getString("id"),
      slug = json.getString("slug"),
      externalRef = json.optStringOrNull("externalRef"),
      name = json.getString("name"),
      description = json.optStringOrNull("description"),
      priceCents = json.optInt("priceCents", 0),
      tags = json.optJSONArray("tags").toStringList(),
      imageUrl = json.optStringOrNull("imageUrl"),
      isAvailable = json.optBoolean("isAvailable", true),
      merchant = EmbedMerchant.fromJson(json.getJSONObject("merchant")),
      model = json.optJSONObject("model")?.let { EmbedModel.fromJson(it) },
    )
  }
}

data class EmbedItemList(
  val items: List<EmbedItem>,
  /** Opaque; changes whenever the list does. Cache keys derive from it. */
  val version: String,
) {
  companion object {
    fun fromJson(json: JSONObject) = EmbedItemList(
      items = json.optJSONArray("items").toObjectList().map { EmbedItem.fromJson(it) },
      version = json.optString("version", ""),
    )
  }
}

enum class EmbedScope(val wire: String) {
  PARTNER("partner"),
  RESTAURANT("restaurant");

  companion object {
    fun fromWire(value: String?): EmbedScope =
      entries.firstOrNull { it.wire == value } ?: RESTAURANT
  }
}

/**
 * What the key in hand is allowed to see. Fetch it once at startup so a
 * revoked or mistyped key fails loudly instead of presenting as an empty menu.
 */
data class EmbedConfig(
  val scope: EmbedScope,
  val ownerName: String,
  /** Every merchant this key can read. One entry for a restaurant-scoped key. */
  val merchants: List<EmbedMerchant>,
) {
  companion object {
    fun fromJson(json: JSONObject) = EmbedConfig(
      scope = EmbedScope.fromWire(json.optStringOrNull("scope")),
      ownerName = json.optString("ownerName", ""),
      merchants = json.optJSONArray("merchants").toObjectList().map { EmbedMerchant.fromJson(it) },
    )
  }
}

/* -- org.json helpers -------------------------------------------------------- */

internal fun JSONObject.optStringOrNull(key: String): String? =
  if (isNull(key)) null else optString(key)

internal fun JSONArray?.toStringList(): List<String> {
  if (this == null) return emptyList()
  return (0 until length()).map { getString(it) }
}

internal fun JSONArray?.toObjectList(): List<JSONObject> {
  if (this == null) return emptyList()
  return (0 until length()).map { getJSONObject(it) }
}
