import Flutter
import Foundation

/// iOS arka plan yukleme koprusu (kanal `bu_kampus/transfers`). Dart tarafi: lib/core/transfers/ios_background_upload.dart.
///
/// Kalici `URLSession` (background) + dosya tabanli `uploadTask(with:fromFile:)`. Govde, kaynak dosyadan parca parca
/// yazilan gecici bir multipart dosyasidir (bellege tamami alinmaz). Basliklar (Authorization, Idempotency-Key...)
/// Dart'tan gelir; arka planda token YENILENMEZ: 401 sonucu oldugu gibi Dart'a teslim edilir.
/// Sonuc (durum kodu + govde) `Application Support/bu_bgup/<anahtar>/result.json` dosyasina yazilir, Dart `bgTake`
/// ile alana dek durur; uygulama yeniden acilinca kuyruk bunu sunucu sonucuyla birlikte tuketir.
///
/// DURUST SINIR: kullanici uygulamayi zorla kapatirsa iOS arka plan oturumunu sonlandirir.
/// UYARI: Bu dosya Windows'ta derlenemedi (macOS/Xcode gerekir); ilk Codemagic derlemesinde dogrulayin.
final class BuBackgroundUploads: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
  static let shared = BuBackgroundUploads()
  private static let sessionId = "tr.com.bukampus.app.bgupload"

  private var channel: FlutterMethodChannel?
  private var pendingCompletion: (() -> Void)?
  private var received: [Int: Data] = [:]
  private let lock = NSLock()

  /// Oturum tembel olusur; ayni kimlikle olusturmak, uygulama arka planda yeniden baslatildiginda eski gorevleri baglar.
  private lazy var session: URLSession = {
    let cfg = URLSessionConfiguration.background(withIdentifier: BuBackgroundUploads.sessionId)
    cfg.sessionSendsLaunchEvents = true
    cfg.isDiscretionary = false
    return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
  }()

  static func register(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "bu_kampus/transfers", binaryMessenger: messenger)
    shared.channel = ch
    ch.setMethodCallHandler { call, result in shared.handle(call, result) }
    _ = shared.session // acilista oturumu ayni kimlikle yeniden bagla
  }

  /// AppDelegate'ten: sistem arka plan olaylari icin uyandirdi.
  static func handleEvents(identifier: String, completion: @escaping () -> Void) {
    if identifier == sessionId {
      shared.lock.lock()
      shared.pendingCompletion = completion
      shared.lock.unlock()
      _ = shared.session
    } else {
      completion()
    }
  }

  // MARK: Dosya yardimcilari

  private static var root: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    return base.appendingPathComponent("bu_bgup", isDirectory: true)
  }

  private static func safe(_ key: String) -> String {
    let ok = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
    return String(key.map { ok.contains($0) ? $0 : "_" })
  }

  private static func dir(_ key: String) -> URL {
    return root.appendingPathComponent(safe(key), isDirectory: true)
  }

  private static func clean(_ s: String) -> String {
    return s.replacingOccurrences(of: "\r", with: " ")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\"", with: "'")
  }

  private static func writeBody(source: URL, dest: URL, boundary: String, field: String, fileName: String, mime: String) throws {
    FileManager.default.createFile(atPath: dest.path, contents: nil)
    let out = try FileHandle(forWritingTo: dest)
    defer { try? out.close() }
    let input = try FileHandle(forReadingFrom: source)
    defer { try? input.close() }
    let head = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(clean(field))\"; filename=\"\(clean(fileName))\"\r\nContent-Type: \(clean(mime))\r\n\r\n"
    try out.write(contentsOf: Data(head.utf8))
    while true {
      let chunk = try autoreleasepool { try input.read(upToCount: 1_048_576) }
      guard let data = chunk, !data.isEmpty else { break }
      try out.write(contentsOf: data)
    }
    try out.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))
  }

  // MARK: Kanal

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "bgUpload": upload(args, result)
    case "bgTake": result(take(args["taskKey"] as? String))
    case "bgPending":
      session.getAllTasks { tasks in
        let keys = tasks.filter { $0.state == .running || $0.state == .suspended }.compactMap { $0.taskDescription }
        DispatchQueue.main.async { result(keys) }
      }
    case "bgCancel":
      let key = args["taskKey"] as? String
      session.getAllTasks { tasks in
        for t in tasks where t.taskDescription == key { t.cancel() }
        DispatchQueue.main.async { result(nil) }
      }
      if let key = key { try? FileManager.default.removeItem(at: BuBackgroundUploads.dir(key)) }
    case "bgCancelAll":
      session.getAllTasks { tasks in
        for t in tasks { t.cancel() }
        DispatchQueue.main.async { result(nil) }
      }
      try? FileManager.default.removeItem(at: BuBackgroundUploads.root)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func upload(_ a: [String: Any], _ result: @escaping FlutterResult) {
    guard let key = a["taskKey"] as? String, let urlStr = a["url"] as? String, let url = URL(string: urlStr),
          url.scheme == "https", let path = a["filePath"] as? String else {
      result(FlutterError(code: "BAD_ARGS", message: "gecersiz yukleme istegi", details: nil))
      return
    }
    let field = a["fileField"] as? String ?? "file"
    let fileName = a["fileName"] as? String ?? "upload.bin"
    let mime = a["mime"] as? String ?? "application/octet-stream"
    let headers = a["headers"] as? [String: String] ?? [:]
    DispatchQueue.global(qos: .userInitiated).async {
      let dir = BuBackgroundUploads.dir(key)
      let body = dir.appendingPathComponent("body.multipart")
      let boundary = "BU" + UUID().uuidString
      do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("result.json"))
        try BuBackgroundUploads.writeBody(source: URL(fileURLWithPath: path), dest: body, boundary: boundary,
                                          field: field, fileName: fileName, mime: mime)
      } catch {
        try? FileManager.default.removeItem(at: dir)
        DispatchQueue.main.async { result(FlutterError(code: "BODY_FAILED", message: error.localizedDescription, details: nil)) }
        return
      }
      var req = URLRequest(url: url)
      req.httpMethod = "POST"
      for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
      req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
      let task = self.session.uploadTask(with: req, fromFile: body)
      task.taskDescription = key
      task.resume()
      DispatchQueue.main.async { result(nil) }
    }
  }

  /// Bitmis sonucu verir ve dosyalari siler; yoksa nil (henuz bitmedi ya da hic baslamadi).
  private func take(_ key: String?) -> [String: Any]? {
    guard let key = key else { return nil }
    let dir = BuBackgroundUploads.dir(key)
    let file = dir.appendingPathComponent("result.json")
    guard let data = try? Data(contentsOf: file),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    try? FileManager.default.removeItem(at: dir)
    return obj
  }

  private func emit(_ method: String, _ args: [String: Any]) {
    DispatchQueue.main.async { self.channel?.invokeMethod(method, arguments: args) }
  }

  // MARK: URLSession temsilcisi

  func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                  totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
    guard let key = task.taskDescription, totalBytesExpectedToSend > 0 else { return }
    emit("bgProgress", ["taskKey": key, "sent": NSNumber(value: totalBytesSent), "total": NSNumber(value: totalBytesExpectedToSend)])
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    lock.lock()
    var buf = received[dataTask.taskIdentifier] ?? Data()
    if buf.count < 65_536 { buf.append(data) } // sonuc govdesi kucuktur; sinirsiz buyumesin
    received[dataTask.taskIdentifier] = buf
    lock.unlock()
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    lock.lock()
    let data = received.removeValue(forKey: task.taskIdentifier) ?? Data()
    lock.unlock()
    guard let key = task.taskDescription else { return }
    let dir = BuBackgroundUploads.dir(key)
    try? FileManager.default.removeItem(at: dir.appendingPathComponent("body.multipart"))
    if let e = error as NSError?, e.domain == NSURLErrorDomain, e.code == NSURLErrorCancelled {
      try? FileManager.default.removeItem(at: dir) // iptal: sonuc uretilmez
      return
    }
    let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
    var res: [String: Any] = [
      "taskKey": key,
      "status": NSNumber(value: status),
      "body": String(data: data, encoding: .utf8) ?? "",
    ]
    if let e = error { res["error"] = e.localizedDescription }
    if let json = try? JSONSerialization.data(withJSONObject: res) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      try? json.write(to: dir.appendingPathComponent("result.json"), options: .atomic)
    }
    emit("bgDone", res)
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    lock.lock()
    let done = pendingCompletion
    pendingCompletion = nil
    lock.unlock()
    // Sistem tamamlayicisi ana kuyrukta cagrilmali.
    DispatchQueue.main.async { done?() }
  }
}
