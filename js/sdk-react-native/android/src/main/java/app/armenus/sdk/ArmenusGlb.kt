package app.armenus.sdk

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Converts embedded WebP textures to PNG for Filament's Android texture decoder. */
internal object ArmenusGlb {
  fun prepare(bytes: ByteArray, decodeWebp: (ByteArray, Int, Int) -> ByteArray = ::decode): ByteArray {
    require(bytes.size >= 20) { "Invalid GLB header" }
    val input = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
    require(input.int == 0x46546c67 && input.int == 2 && input.int == bytes.size) { "Invalid GLB header" }
    val jsonLength = input.int
    require(input.int == 0x4e4f534a && jsonLength >= 0 && jsonLength <= input.remaining()) { "Invalid GLB JSON" }
    val jsonBytes = ByteArray(jsonLength).also { input.get(it) }
    val json = JSONObject(String(jsonBytes, Charsets.UTF_8))
    val images = json.optJSONArray("images") ?: return bytes
    if ((0 until images.length()).none { images.getJSONObject(it).optString("mimeType") == "image/webp" }) return bytes
    require(input.remaining() >= 8) { "Missing GLB binary data" }
    val binaryLength = input.int
    require(input.int == 0x004e4942 && binaryLength >= 0 && binaryLength <= input.remaining()) { "Invalid GLB binary data" }
    val binary = ByteArray(binaryLength).also { input.get(it) }
    val output = ByteArrayOutputStream().apply { write(binary) }
    val views = json.getJSONArray("bufferViews")
    for (index in 0 until images.length()) {
      val image = images.getJSONObject(index)
      if (image.optString("mimeType") != "image/webp") continue
      require(image.has("bufferView")) { "WebP texture must be embedded in GLB" }
      val view = views.getJSONObject(image.getInt("bufferView"))
      val offset = view.optInt("byteOffset", 0)
      val length = view.getInt("byteLength")
      require(view.optInt("buffer", 0) == 0 && offset >= 0 && length > 0 && offset <= binary.size - length) { "Invalid WebP texture range" }
      val png = decodeWebp(binary, offset, length)
      while (output.size() % 4 != 0) output.write(0)
      val replacement = JSONObject().put("buffer", 0).put("byteOffset", output.size()).put("byteLength", png.size)
      image.put("bufferView", views.length()).put("mimeType", "image/png")
      views.put(replacement)
      output.write(png)
    }
    json.optJSONArray("textures")?.let { textures ->
      for (index in 0 until textures.length()) {
        val texture = textures.getJSONObject(index)
        val extensions = texture.optJSONObject("extensions") ?: continue
        val webp = extensions.optJSONObject("EXT_texture_webp") ?: continue
        texture.put("source", webp.getInt("source"))
        extensions.remove("EXT_texture_webp")
        if (extensions.length() == 0) texture.remove("extensions")
      }
    }
    for (key in arrayOf("extensionsUsed", "extensionsRequired")) {
      json.optJSONArray(key)?.let { values ->
        val kept = JSONArray()
        for (index in 0 until values.length()) if (values.getString(index) != "EXT_texture_webp") kept.put(values.getString(index))
        if (kept.length() == 0) json.remove(key) else json.put(key, kept)
      }
    }
    json.getJSONArray("buffers").getJSONObject(0).put("byteLength", output.size())
    while (output.size() % 4 != 0) output.write(0)
    // cgltf compares MIME tokens directly, so avoid Android JSONObject slash escapes.
    val encoded = json.toString().replace("\\/", "/").toByteArray(Charsets.UTF_8)
    val paddedLength = (encoded.size + 3) / 4 * 4
    return ByteBuffer.allocate(12 + 8 + paddedLength + 8 + output.size()).order(ByteOrder.LITTLE_ENDIAN).apply {
      putInt(0x46546c67); putInt(2); putInt(capacity())
      putInt(paddedLength); putInt(0x4e4f534a); put(encoded)
      repeat(paddedLength - encoded.size) { put(32.toByte()) }
      putInt(output.size()); putInt(0x004e4942); put(output.toByteArray())
    }.array()
  }

  private fun decode(bytes: ByteArray, offset: Int, length: Int): ByteArray {
    val bitmap = BitmapFactory.decodeByteArray(bytes, offset, length)
      ?: error("Cannot decode model WebP texture")
    return try {
      ByteArrayOutputStream().also {
        check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) { "Cannot convert model WebP texture" }
      }.toByteArray()
    } finally { bitmap.recycle() }
  }
}
