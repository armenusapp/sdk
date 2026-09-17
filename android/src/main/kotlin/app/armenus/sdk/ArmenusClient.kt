package app.armenus.sdk

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import org.json.JSONException
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import java.net.URLEncoder
import kotlin.coroutines.coroutineContext
import kotlin.random.Random

/**
 * Client for the Armenus embed API.
 *
 * Read-only, because the credential it holds is public. Anything that costs
 * money or changes data needs the secret partner key and a server to hold it.
 *
 * Plain `HttpURLConnection` on the IO dispatcher: no HTTP client library is
 * pulled into a host app for five GET endpoints.
 *
 * @param publishableKey A `pk_` key. Safe to ship in an app by construction.
 * @param baseUrl Override for staging or self-hosted deployments.
 * @param timeoutMs Per-attempt ceiling. The default in every HTTP stack is
 *   "wait forever", and the caller here is usually a phone rendering a card.
 * @param retries Attempts for retryable failures, including the first. Only
 *   idempotent reads exist in this API, so retrying is always safe here.
 * @throws IllegalArgumentException for anything that is not a publishable key.
 *   Thrown at construction on purpose: the common integration mistake is
 *   pasting the secret `ak_` key into an app, which would work all the way
 *   into production.
 */
class ArmenusClient(
  publishableKey: String,
  baseUrl: String = DEFAULT_BASE_URL,
  private val timeoutMs: Int = 8_000,
  retries: Int = 2,
) {
  private val key: String
  private val baseUrl: String = baseUrl.trimEnd('/')
  private val retries: Int = maxOf(1, retries)

  init {
    require(publishableKey.startsWith("pk_")) {
      if (publishableKey.startsWith("ak_")) {
        "That is a secret API key. Never ship an ak_ key in client code. Use a publishable pk_ key."
      } else {
        "A publishable key (pk_...) is required."
      }
    }
    key = publishableKey
  }

  /**
   * What this key can see. Call it once at startup so a revoked or mistyped
   * key fails here rather than presenting as an empty catalogue.
   */
  suspend fun config(): EmbedConfig = request("/embed/config") { EmbedConfig.fromJson(it) }

  /** One dish, by Armenus id. */
  suspend fun item(id: String): EmbedItem =
    request("/embed/items/${encode(id)}") { EmbedItem.fromJson(it) }

  /** One dish, by the host app's own identifier, so it never has to store ours. */
  suspend fun itemByRef(merchantId: String, externalRef: String): EmbedItem =
    request("/embed/merchants/${encode(merchantId)}/items/by-ref/${encode(externalRef)}") {
      EmbedItem.fromJson(it)
    }

  /**
   * Every dish on one merchant. `withModel` filters to dishes with a ready,
   * published model and paginates correctly against that filter.
   */
  suspend fun items(
    merchantId: String,
    withModel: Boolean = false,
    limit: Int? = null,
    offset: Int? = null,
  ): EmbedItemList {
    val query = LinkedHashMap<String, String>()
    if (withModel) query["withModel"] = "true"
    if (limit != null) query["limit"] = limit.toString()
    if (offset != null) query["offset"] = offset.toString()
    return request("/embed/merchants/${encode(merchantId)}/items", query) { EmbedItemList.fromJson(it) }
  }

  /**
   * Up to 50 dishes in one request. A grid needs twenty models at once, and
   * twenty round trips over restaurant wifi is the difference between a grid
   * that pops in and one that trickles.
   */
  suspend fun itemsByIds(ids: List<String>): EmbedItemList {
    if (ids.isEmpty()) {
      // Short-circuited rather than sent: the API rejects an empty `ids` as
      // malformed, and an empty list is an ordinary state for a grid that
      // has not resolved its rows yet.
      return EmbedItemList(emptyList(), "")
    }
    return request("/embed/items", mapOf("ids" to ids.joinToString(","))) { EmbedItemList.fromJson(it) }
  }

  /* -- transport ------------------------------------------------------------ */

  private suspend fun <T> request(
    path: String,
    query: Map<String, String> = emptyMap(),
    parse: (JSONObject) -> T,
  ): T {
    var lastError: ArmenusException? = null

    repeat(retries) { attempt ->
      try {
        return attempt(path, query, parse)
      } catch (error: ArmenusException) {
        // A cancelled coroutine is not a failure to retry around: the screen
        // it was feeding is gone.
        coroutineContext.ensureActive()
        if (!error.isRetryable) throw error
        lastError = error

        if (attempt < retries - 1) {
          // Exponential and jittered. Without jitter a restaurant full of
          // phones that failed on the same blip retries in lockstep.
          val backoff = 200L shl attempt
          delay(backoff + Random.nextLong(backoff + 1))
        }
      }
    }

    throw lastError ?: ArmenusException(0, "network_error", "Request failed")
  }

  private suspend fun <T> attempt(
    path: String,
    query: Map<String, String>,
    parse: (JSONObject) -> T,
  ): T = withContext(Dispatchers.IO) {
    val connection = (URL(buildUrl(path, query)).openConnection() as HttpURLConnection).apply {
      requestMethod = "GET"
      connectTimeout = timeoutMs
      readTimeout = timeoutMs
      instanceFollowRedirects = true
      setRequestProperty("Authorization", "Bearer $key")
      setRequestProperty("Accept", "application/json")
    }

    try {
      val status = try {
        connection.responseCode
      } catch (error: SocketTimeoutException) {
        throw ArmenusException(0, "timeout", "Request timed out after ${timeoutMs}ms", cause = error)
      } catch (error: IOException) {
        throw ArmenusException(0, "network_error", error.message ?: "Network error", cause = error)
      }

      val stream = if (status in 200..299) connection.inputStream else connection.errorStream
      val body = stream?.use { it.readBytes().toString(Charsets.UTF_8) } ?: ""

      if (status !in 200..299) {
        // The API always sends a JSON error body, but a proxy or a captive
        // portal in between may not, so parsing it must never be what
        // produces the error the caller sees.
        val json = runCatching { JSONObject(body) }.getOrNull()
        throw ArmenusException(
          status = status,
          code = json?.optStringOrNull("error") ?: "http_error",
          message = json?.optStringOrNull("message") ?: "Request failed with status $status",
          details = json?.opt("details")?.takeUnless { it == JSONObject.NULL }?.toString(),
        )
      }

      try {
        parse(JSONObject(body))
      } catch (error: JSONException) {
        throw ArmenusException(status, "decode_error", "Could not decode the API response: ${error.message}", cause = error)
      }
    } finally {
      connection.disconnect()
    }
  }

  private fun buildUrl(path: String, query: Map<String, String>): String {
    if (query.isEmpty()) return baseUrl + path
    val encoded = query.entries.joinToString("&") { (name, value) -> "${encode(name)}=${encode(value)}" }
    return "$baseUrl$path?$encoded"
  }

  companion object {
    const val DEFAULT_BASE_URL = "https://api.armenus.app/v1"

    /**
     * `encodeURIComponent` semantics, so an id containing `/` or `?` cannot
     * change the route it is sent to. `URLEncoder` is form encoding, hence
     * the space fix-up.
     */
    internal fun encode(segment: String): String =
      URLEncoder.encode(segment, "UTF-8").replace("+", "%20")
  }
}
