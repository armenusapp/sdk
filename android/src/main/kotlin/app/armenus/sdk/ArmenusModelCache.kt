package app.armenus.sdk

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap

/**
 * Disk cache for meshes.
 *
 * Android needs this less than iOS does: Scene Viewer takes a remote URL and
 * fetches the GLB itself, so there is no hard requirement for a local file. It
 * earns its place on the inline path instead. Filament loads from a byte
 * buffer, and re-downloading a few megabytes every time a card scrolls back
 * into view is the difference between a feed that feels instant and one that
 * flickers.
 *
 * Kept in `cacheDir`, so the OS may evict it under storage pressure and it
 * never counts against the user's backup quota.
 */
object ArmenusModelCache {
  private const val MAX_BYTES = 256L * 1024 * 1024

  /** One download per URL, however many cards ask at once. */
  private val inFlight = ConcurrentHashMap<String, Any>()

  private fun directory(context: Context): File =
    File(context.cacheDir, "armenus-models").apply { mkdirs() }

  private fun keyFor(url: String): String {
    val digest = MessageDigest.getInstance("SHA-256").digest(url.toByteArray())
    val hex = digest.joinToString("") { "%02x".format(it) }
    // The extension is preserved because Filament dispatches on it to choose
    // between the glTF and GLB loaders.
    val ext = url.substringAfterLast('.', "glb").substringBefore('?').take(8)
    return "$hex.$ext"
  }

  /** Local file for a remote URL, downloading it if absent. */
  suspend fun file(context: Context, url: String): File =
    withContext(Dispatchers.IO) { fileBlocking(context, url) }

  /**
   * Blocking form of [file]. Call it from a background thread, never from the
   * UI thread.
   */
  fun fileBlocking(context: Context, url: String): File {
    val target = File(directory(context), keyFor(url))
    if (target.exists() && target.length() > 0) {
      target.setLastModified(System.currentTimeMillis())
      return target
    }

    val lock = inFlight.getOrPut(url) { Any() }
    synchronized(lock) {
      // Another thread may have finished it while this one waited.
      if (target.exists() && target.length() > 0) return target

      // Downloaded to a sibling and renamed, so a kill mid-write cannot leave
      // a truncated file that is then served from cache forever.
      val partial = File(target.parentFile, "${target.name}.part")
      val connection = (URL(url).openConnection() as HttpURLConnection).apply {
        connectTimeout = 15_000
        readTimeout = 30_000
        instanceFollowRedirects = true
      }

      try {
        if (connection.responseCode !in 200..299) {
          throw ArmenusException(
            connection.responseCode,
            "download_failed",
            "Model download failed with HTTP ${connection.responseCode}",
          )
        }
        connection.inputStream.use { input ->
          partial.outputStream().use { output -> input.copyTo(output) }
        }
        if (!partial.renameTo(target)) {
          throw ArmenusException(0, "download_failed", "Could not finalise cached model")
        }
      } finally {
        connection.disconnect()
        partial.delete()
        inFlight.remove(url)
      }
    }

    evictIfNeeded(context)
    return target
  }

  fun totalBytes(context: Context): Long =
    directory(context).listFiles()?.sumOf { it.length() } ?: 0L

  fun clear(context: Context) {
    directory(context).listFiles()?.forEach { it.delete() }
  }

  /**
   * Least-recently-used eviction, down to half the ceiling. Halved rather than
   * trimmed exactly so a session sitting at the boundary does not sweep after
   * every download.
   */
  private fun evictIfNeeded(context: Context) {
    val files = directory(context).listFiles()?.toMutableList() ?: return
    var total = files.sumOf { it.length() }
    if (total <= MAX_BYTES) return

    files.sortBy { it.lastModified() }
    val target = MAX_BYTES / 2
    for (file in files) {
      if (total <= target) break
      total -= file.length()
      file.delete()
    }
  }
}
