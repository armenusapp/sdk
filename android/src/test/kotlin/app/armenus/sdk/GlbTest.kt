package app.armenus.sdk

import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test

class GlbTest {
  private fun glb(json: String, binary: ByteArray = byteArrayOf(1, 2, 3, 4)): ByteArray {
    val text = json.padEnd((json.length + 3) / 4 * 4).toByteArray()
    return ByteBuffer.allocate(28 + text.size + binary.size).order(ByteOrder.LITTLE_ENDIAN).apply {
      putInt(0x46546c67); putInt(2); putInt(capacity())
      putInt(text.size); putInt(0x4e4f534a); put(text)
      putInt(binary.size); putInt(0x004e4942); put(binary)
    }.array()
  }
  private val document = """{"asset":{"version":"2.0"},"buffers":[{"byteLength":4}],"bufferViews":[{"buffer":0,"byteLength":4}],"images":[{"bufferView":0,"mimeType":"image/webp"}],"textures":[{"extensions":{"EXT_texture_webp":{"source":0}}}],"extensionsUsed":["EXT_texture_webp","KHR_mesh_quantization"],"extensionsRequired":["EXT_texture_webp"]}"""

  @Test fun leavesOrdinaryGlbUntouched() {
    val original = glb("""{"asset":{"version":"2.0"}}""")
    assertSame(original, ArmenusGlb.prepare(original) { _, _, _ -> error("Unexpected conversion") })
  }
  @Test fun replacesWebpTextureAndPreservesOtherExtensionsAndBinary() {
    val converted = ArmenusGlb.prepare(glb(document)) { bytes, offset, length ->
      assertArrayEquals(byteArrayOf(1, 2, 3, 4), bytes.copyOfRange(offset, offset + length))
      byteArrayOf(9, 8, 7)
    }
    val buffer = ByteBuffer.wrap(converted).order(ByteOrder.LITTLE_ENDIAN)
    assertEquals(converted.size, buffer.getInt(8))
    val length = buffer.getInt(12)
    val json = JSONObject(String(converted.copyOfRange(20, 20 + length)))
    assertEquals("image/png", json.getJSONArray("images").getJSONObject(0).getString("mimeType"))
    assertEquals(0, json.getJSONArray("textures").getJSONObject(0).getInt("source"))
    assertFalse(json.has("extensionsRequired"))
    assertEquals("KHR_mesh_quantization", json.getJSONArray("extensionsUsed").getString(0))
    assertEquals(7, json.getJSONArray("buffers").getJSONObject(0).getInt("byteLength"))
    assertArrayEquals(byteArrayOf(1, 2, 3, 4, 9, 8, 7, 0), converted.copyOfRange(28 + length, converted.size))
  }
  @Test fun rejectsOutOfRangeTextureBeforeDecoder() {
    val invalid = document.replace("\"buffer\":0,\"byteLength\":4", "\"buffer\":0,\"byteOffset\":4,\"byteLength\":4")
    assertThrows(IllegalArgumentException::class.java) {
      ArmenusGlb.prepare(glb(invalid)) { _, _, _ -> error("Decoder must not run") }
    }
  }
  @Test fun rejectsTruncatedGlb() {
    assertThrows(IllegalArgumentException::class.java) { ArmenusGlb.prepare(glb(document).dropLast(1).toByteArray()) }
  }
}
