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
    let group = DispatchGroup()
    for (key, identifier) in [("imageUrl", "photo"), ("senderAvatarUrl", "avatar")] {
      guard let raw = copy.userInfo[key] as? String, let url = URL(string: raw), url.scheme == "https", url.user == nil else { continue }
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

  private func finish() {
    lock.lock()
    let completion = handler; handler = nil; let result = content
    lock.unlock()
    if let completion = completion, let result = result { completion(result) }
  }

  override func serviceExtensionTimeWillExpire() { tasks.forEach { $0.cancel() }; finish() }
}
