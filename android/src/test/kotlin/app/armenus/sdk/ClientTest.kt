package app.armenus.sdk

import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Drives the client against a local HTTP server so the transport is tested
 * for real: what it sends, and how it reacts to what comes back.
 */
class ClientTest {
  private lateinit var server: TestServer

  @Before
  fun start() {
    server = TestServer()
  }

  @After
  fun stop() {
    server.close()
  }

  private fun client(retries: Int = 2) = ArmenusClient(
    publishableKey = "pk_abc123_secretpart",
    baseUrl = "http://127.0.0.1:${server.port}/v1",
    timeoutMs = 2_000,
    retries = retries,
  )

  @Test
  fun rejectsSecretAndMalformedKeys() {
    val secret = assertThrows(IllegalArgumentException::class.java) { ArmenusClient("ak_secret_key") }
    assertTrue(secret.message!!.contains("secret"))
    assertThrows(IllegalArgumentException::class.java) { ArmenusClient("") }
    ArmenusClient("pk_ok")
  }

  @Test
  fun sendsBearerKeyAndEncodesPathSegments() = runBlocking {
    server.responder = { 200 to ITEM_JSON }

    val item = client().itemByRef("m/1", "SKU 12?4")
    assertEquals("SKU-1234", item.externalRef)
    assertNull(item.model!!.usdzUrl)
    assertEquals(UsdzStatus.PROCESSING, item.model!!.usdzStatus)
    assertNull(item.description)
    assertNull(item.model!!.glbBytes)

    val request = server.requests.single()
    assertEquals("Bearer pk_abc123_secretpart", request.headers["authorization"])
    assertEquals("/v1/embed/merchants/m%2F1/items/by-ref/SKU%2012%3F4", request.rawPath)
  }

  @Test
  fun listQueryParameters() = runBlocking {
    server.responder = { 200 to """{"items":[],"version":"v9"}""" }

    val list = client().items("m-1", withModel = true, limit = 20, offset = 40)
    assertEquals("v9", list.version)
    assertEquals("withModel=true&limit=20&offset=40", server.requests.single().query)
  }

  @Test
  fun emptyIdListIsNotSent() = runBlocking {
    val list = client().itemsByIds(emptyList())
    assertTrue(list.items.isEmpty())
    assertTrue(server.requests.isEmpty())
  }

  @Test
  fun authErrorsAreNotRetried() = runBlocking {
    server.responder = { 401 to """{"error":"unauthorized","message":"A publishable key is required."}""" }

    val error = assertThrows(ArmenusException::class.java) { runBlocking { client().config() } }
    assertEquals(401, error.status)
    assertEquals("unauthorized", error.code)
    assertTrue(error.isAuthError)
    assertFalse(error.isRetryable)
    assertEquals(1, server.requests.size)
  }

  @Test
  fun serverFaultsAreRetriedThenSucceed() = runBlocking {
    var calls = 0
    server.responder = {
      calls += 1
      if (calls == 1) 503 to """{"error":"unavailable","message":"try again"}"""
      else 200 to """{"scope":"restaurant","ownerName":"Z","merchants":[]}"""
    }

    val config = client(retries = 3).config()
    assertEquals(EmbedScope.RESTAURANT, config.scope)
    assertEquals(2, server.requests.size)
  }

  @Test
  fun nonJsonErrorBodyStillProducesAnError() {
    server.responder = { 502 to "<html>bad gateway</html>" }

    val error = assertThrows(ArmenusException::class.java) { runBlocking { client(retries = 1).config() } }
    assertEquals(502, error.status)
    assertEquals("http_error", error.code)
    assertTrue(error.isRetryable)
  }

  @Test
  fun errorDetailsAreCarriedAsJson() {
    server.responder = { 400 to """{"error":"bad_request","message":"nope","details":[{"path":"ids","message":"too many"}]}""" }

    val error = assertThrows(ArmenusException::class.java) { runBlocking { client(retries = 1).itemsByIds(listOf("a")) } }
    assertEquals("""[{"path":"ids","message":"too many"}]""", error.details)
  }

  companion object {
    const val ITEM_JSON = """
      {
        "id": "item-1", "slug": "burger", "externalRef": "SKU-1234", "name": "Burger",
        "description": null, "priceCents": 847, "tags": ["beef"], "imageUrl": null,
        "isAvailable": true,
        "merchant": {"id": "m-1", "slug": "zburger", "name": "Z Burger", "currency": "USD", "locale": "en-US"},
        "model": {
          "id": "model-1", "glbUrl": "https://cdn.test/a.glb", "usdzUrl": null,
          "usdzStatus": "processing", "posterUrl": "https://cdn.test/a.webp",
          "physicalSizeM": 0.22, "glbBytes": null,
          "viewSettings": {"cameraOrbit": "0deg 75deg 105%", "cameraTarget": "auto auto auto",
            "fieldOfView": "auto", "exposure": 1, "shadowIntensity": 1, "autoRotate": true, "arScale": 1}
        }
      }
    """
  }
}
