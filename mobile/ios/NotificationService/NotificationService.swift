import UserNotifications
import ImageIO
import UIKit

/// Adds the per-recipient signed thumbnails supplied by the backend. Text delivery never waits indefinitely.
final class NotificationService: UNNotificationServiceExtension {
  private var handler: ((UNNotificationContent) -> Void)?
  private var content: UNMutableNotificationContent?
  private var tasks: [URLSessionDownloadTask] = []
  private let lock = NSLock()

  override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    handler = contentHandler
    guard let copy = request.content.mutableCopy() as? UNMutableNotificationContent else { contentHandler(request.content); handler = nil; return }
    content = copy
    normalizeCategory(copy)
    applyInterruptionLevel(copy)
    let group = DispatchGroup()
    for (key, identifier) in [("imageUrl", "photo"), ("senderAvatarUrl", "avatar")] {
      guard let raw = copy.userInfo[key] as? String, let url = URL(string: raw), isAllowedImageURL(url) else { continue }
      group.enter()
      var download = URLRequest(url: url); download.timeoutInterval = 5
      let task = URLSession.shared.downloadTask(with: download) { [weak self] file, response, error in
        defer { group.leave() }
        guard let self = self, error == nil, let file = file, let response = response as? HTTPURLResponse,
              response.statusCode == 200, response.url?.host == url.host,
              let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
              let size = attributes[.size] as? NSNumber,
              size.intValue <= 1_048_576,
              let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 600,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary),
              let bytes = UIImage(cgImage: image).jpegData(compressionQuality: 0.85) else { return }
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".jpg")
        do {
          try bytes.write(to: destination)
          let attachment = try UNNotificationAttachment(identifier: identifier, url: destination)
          self.lock.lock(); self.content?.attachments.append(attachment); self.lock.unlock()
        } catch { /* Preserve the original text if a thumbnail is unavailable. */ }
      }
      tasks.append(task); task.resume()
    }
    group.notify(queue: .main) { [weak self] in self?.finish() }
  }

  /// Sunucu zaten yalniz PUBLIC_WEB_URL ana makinesi / *.bingol.edu.tr adreslerini gonderir; burada ek savunma:
  /// yalniz https, kullanici bilgisi yok, varsayilan port, IP/yerel ad degil (indirme yonlendirmesi ayni makineyle sinirli).
  private func isAllowedImageURL(_ url: URL) -> Bool {
    guard url.scheme == "https", url.user == nil, url.password == nil, url.port == nil || url.port == 443,
          let host = url.host?.lowercased(), host.contains("."), host != "localhost",
          host.range(of: "^[0-9.]+$", options: .regularExpression) == nil, !host.contains(":") else { return false }
    return true
  }

  /// Sunucu `aps.category`'yi `BU_<style>` gondermezse (eski surum/yedek yol) yukteki `style` ile duzeltir;
  /// boylece aksiyon dugmeleri ve NotificationContent karti yine de devreye girer.
  private func normalizeCategory(_ copy: UNMutableNotificationContent) {
    guard !copy.categoryIdentifier.hasPrefix("BU_"),
          let style = copy.userInfo["style"] as? String, !style.isEmpty,
          style.range(of: "^[A-Z_]{1,32}$", options: .regularExpression) != nil else { return }
    copy.categoryIdentifier = "BU_" + style
  }

  /// Sinav ve guvenlik (ve `severity=critical`) bildirimleri "time-sensitive" teslim edilir (iOS 15+;
  /// uygulamada com.apple.developer.usernotifications.time-sensitive yetkisi gerekir). Sosyal `passive` kalir:
  /// sunucu `interruption-level` gonderdiyse onu asla yukseltmeyiz/dusurmeyiz (yalniz `active` ise yukseltilir).
  private func applyInterruptionLevel(_ copy: UNMutableNotificationContent) {
    guard #available(iOS 15.0, *), copy.interruptionLevel == .active else { return }
    let severity = (copy.userInfo["severity"] as? String)?.lowercased()
    let category = copy.categoryIdentifier
    if severity == "critical" || category == "BU_EXAM" || category == "BU_SECURITY" {
      copy.interruptionLevel = .timeSensitive
      copy.relevanceScore = 1.0
    }
  }

  private func finish() {
    lock.lock()
    let completion = handler; handler = nil; let result = content
    lock.unlock()
    if let completion = completion, let result = result { completion(result) }
  }

  override func serviceExtensionTimeWillExpire() { tasks.forEach { $0.cancel() }; finish() }
}
