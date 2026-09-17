import CryptoKit
import Foundation

/// Disk cache for meshes.
///
/// Not an optimisation bolted on afterwards: AR Quick Look refuses remote URLs
/// and needs a local file, so the download has to happen regardless. Once it
/// does, caching it is nearly free and is where the perceived speed comes
/// from. The second view of a dish opens instantly instead of pulling a few
/// megabytes again.
///
/// Lives in Caches, not Documents. These files are reproducible from the
/// network, so the OS is entitled to evict them under storage pressure, and
/// putting them in Documents would back a restaurant's whole catalogue up to
/// the user's iCloud quota.
public final class ArmenusModelCache: @unchecked Sendable {
  public static let shared = ArmenusModelCache()

  /// Bounded so a heavy browsing session cannot fill the device.
  public var maxBytes: Int64 = 256 * 1024 * 1024

  private let directory: URL
  private let session: URLSession

  /// In-flight downloads, so N cards asking for one dish make one request.
  private var inFlight: [String: [(Result<URL, Error>) -> Void]] = [:]
  private let lock = NSLock()

  init(directoryName: String = "armenus-models") {
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    directory = caches.appendingPathComponent(directoryName, isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let configuration = URLSessionConfiguration.default
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.timeoutIntervalForRequest = 30
    session = URLSession(configuration: configuration)
  }

  /// Local file for a remote URL, downloading it if absent.
  public func file(for remoteURL: String) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      file(for: remoteURL) { url, error in
        if let url {
          continuation.resume(returning: url)
        } else {
          continuation.resume(throwing: error ?? ArmenusCacheError.empty)
        }
      }
    }
  }

  /// Completion-handler form of ``file(for:)``.
  ///
  /// The filename is a SHA-256 of the URL plus the original extension. The
  /// extension is not cosmetic: both `QLPreviewController` and `SCNScene`
  /// dispatch on it, and a USDZ saved without one is rejected as an unknown
  /// type rather than failing usefully.
  public func file(for remoteURL: String, completion: @escaping (URL?, Error?) -> Void) {
    guard let url = URL(string: remoteURL) else {
      completion(nil, ArmenusCacheError.badURL)
      return
    }

    let ext = url.pathExtension.isEmpty ? "usdz" : url.pathExtension
    let digest = SHA256.hash(data: Data(remoteURL.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
    let destination = directory.appendingPathComponent("\(digest).\(ext)")

    if FileManager.default.fileExists(atPath: destination.path) {
      // Touch it, so the eviction sweep treats recently used files as warm.
      try? FileManager.default.setAttributes(
        [.modificationDate: Date()], ofItemAtPath: destination.path)
      completion(destination, nil)
      return
    }

    // Coalesce: a grid of cards all asking for the same dish must not start a
    // download each.
    lock.lock()
    if inFlight[digest] != nil {
      inFlight[digest]?.append { result in
        switch result {
        case .success(let url): completion(url, nil)
        case .failure(let error): completion(nil, error)
        }
      }
      lock.unlock()
      return
    }
    inFlight[digest] = []
    lock.unlock()

    let task = session.downloadTask(with: url) { [weak self] temp, response, error in
      guard let self else { return }

      let result: Result<URL, Error>
      if let error {
        result = .failure(error)
      } else if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        result = .failure(ArmenusCacheError.http(http.statusCode))
      } else if let temp {
        do {
          // Atomic move. A half-written file left behind by a kill would
          // otherwise be served from cache forever as a corrupt model.
          try? FileManager.default.removeItem(at: destination)
          try FileManager.default.moveItem(at: temp, to: destination)
          result = .success(destination)
        } catch {
          result = .failure(error)
        }
      } else {
        result = .failure(ArmenusCacheError.empty)
      }

      self.lock.lock()
      let waiters = self.inFlight.removeValue(forKey: digest) ?? []
      self.lock.unlock()

      switch result {
      case .success(let url):
        completion(url, nil)
        waiters.forEach { $0(.success(url)) }
      case .failure(let error):
        completion(nil, error)
        waiters.forEach { $0(.failure(error)) }
      }

      self.evictIfNeeded()
    }
    task.resume()
  }

  public func totalBytes() -> Int64 {
    contents().reduce(0) { $0 + $1.size }
  }

  public func clear() {
    for file in contents() {
      try? FileManager.default.removeItem(at: file.url)
    }
  }

  /// Least-recently-used eviction, down to half the ceiling. Halved rather
  /// than trimmed to the limit so a session hovering at the boundary does not
  /// sweep after every download.
  private func evictIfNeeded() {
    var files = contents()
    var total = files.reduce(Int64(0)) { $0 + $1.size }
    guard total > maxBytes else { return }

    files.sort { $0.accessed < $1.accessed }
    let target = maxBytes / 2
    for file in files where total > target {
      try? FileManager.default.removeItem(at: file.url)
      total -= file.size
    }
  }

  private struct Entry {
    let url: URL
    let size: Int64
    let accessed: Date
  }

  private func contents() -> [Entry] {
    let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
    let urls = (try? FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: keys)) ?? []

    return urls.compactMap { url in
      guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
      return Entry(
        url: url,
        size: Int64(values.fileSize ?? 0),
        accessed: values.contentModificationDate ?? .distantPast)
    }
  }
}

public enum ArmenusCacheError: LocalizedError {
  case badURL
  case empty
  case http(Int)

  public var errorDescription: String? {
    switch self {
    case .badURL: return "Malformed model URL"
    case .empty: return "Download produced no file"
    case .http(let code): return "Model download failed with HTTP \(code)"
    }
  }
}
