package app.armenus.sdk

import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.concurrent.thread

/**
 * A minimal HTTP/1.1 server on a loopback port.
 *
 * Enough to exercise the client for real. The JDK's own `com.sun.net.httpserver`
 * is hidden from Android unit-test compilation, which builds against the
 * android.jar stubs, so this uses plain sockets instead.
 */
class TestServer : AutoCloseable {
  data class Request(val method: String, val rawPath: String, val headers: Map<String, String>) {
    val query: String? get() = rawPath.substringAfter('?', "").ifEmpty { null }
  }

  @Volatile var responder: (Request) -> Pair<Int, String> = { 200 to "{}" }
  val requests = CopyOnWriteArrayList<Request>()

  private val socket = ServerSocket(0, 50, InetAddress.getLoopbackAddress())
  val port: Int get() = socket.localPort

  @Volatile private var running = true

  init {
    thread(isDaemon = true, name = "armenus-test-server") {
      while (running) {
        val client = try {
          socket.accept()
        } catch (_: Exception) {
          break
        }
        thread(isDaemon = true) { handle(client) }
      }
    }
  }

  private fun handle(client: Socket) = client.use { connection ->
    val reader = BufferedReader(InputStreamReader(connection.getInputStream(), Charsets.ISO_8859_1))
    val requestLine = reader.readLine() ?: return@use
    val parts = requestLine.split(' ')
    val headers = LinkedHashMap<String, String>()
    while (true) {
      val line = reader.readLine() ?: break
      if (line.isEmpty()) break
      val index = line.indexOf(':')
      if (index > 0) headers[line.substring(0, index).trim().lowercase()] = line.substring(index + 1).trim()
    }

    val request = Request(parts.getOrElse(0) { "" }, parts.getOrElse(1) { "/" }, headers)
    requests += request
    val (status, body) = responder(request)
    val bytes = body.toByteArray(Charsets.UTF_8)
    val head = "HTTP/1.1 $status ${reason(status)}\r\n" +
      "Content-Type: application/json\r\n" +
      "Content-Length: ${bytes.size}\r\n" +
      "Connection: close\r\n\r\n"
    val output = connection.getOutputStream()
    output.write(head.toByteArray(Charsets.ISO_8859_1))
    output.write(bytes)
    output.flush()
  }

  private fun reason(status: Int) = when (status) {
    200 -> "OK"
    400 -> "Bad Request"
    401 -> "Unauthorized"
    502 -> "Bad Gateway"
    503 -> "Service Unavailable"
    else -> "Status"
  }

  override fun close() {
    running = false
    socket.close()
  }
}
