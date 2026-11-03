import UIKit
import UserNotifications
import UserNotificationsUI

/// Expanded push content; collapsed/lock-screen decoration is owned by iOS.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
  private let stack = UIStackView()
  private let navy = UIColor(red: 0.09, green: 0.12, blue: 0.20, alpha: 1)
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    stack.axis = .vertical; stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 14),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -14)
    ])
  }

  private func text(_ value: String, size: CGFloat, bold: Bool = false, color: UIColor? = nil) -> UILabel {
    let label = UILabel(); label.text = value; label.numberOfLines = 0
    label.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
    label.textColor = color ?? navy; return label
  }

  func didReceive(_ notification: UNNotification) {
    loadViewIfNeeded()
    stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let content = notification.request.content
    let data = content.userInfo
    let style = content.categoryIdentifier.replacingOccurrences(of: "BU_", with: "")
    let locale = (data["locale"] as? String) ?? Locale.preferredLanguages.first ?? "tr"
    func label(_ tr: String, _ en: String, _ ar: String) -> String { locale.hasPrefix("ar") ? ar : locale.hasPrefix("en") ? en : tr }
    let section: String
    switch style {
    case "CHAT_DIRECT": section = label("Sohbet", "Chat", "محادثة")
    case "CHAT_GROUP": section = label("Kulüp Odası", "Group chat", "محادثة جماعية")
    case "CHAT_MEDIA": section = label("Medya", "Media", "وسائط")
    case "EVENT_REMINDER", "EVENT_UPDATE", "EVENT_ADMISSION": section = label("Etkinlik", "Event", "فعالية")
    case "EXAM", "ACADEMIC": section = label("Akademik", "Academic", "أكاديمي")
    case "POLL": section = label("Anket", "Poll", "استطلاع")
    case "MEAL": section = label("Bugünün Menüsü", "Today's menu", "قائمة اليوم")
    case "SECURITY": section = label("Güvenlik", "Security", "الأمان")
    case "SUPPORT": section = label("Destek Masası", "Support", "الدعم")
    default: section = label("Bildirim", "Notification", "إشعار")
    }
    stack.addArrangedSubview(text("BU KAMPÜS · " + section, size: 11, bold: true, color: .systemRed))
    let row = UIStackView(); row.axis = .horizontal; row.alignment = .top; row.spacing = 12
    let avatar = UIImageView(image: UIImage(systemName: style.hasPrefix("CHAT") ? "person.circle.fill" : "bell.circle.fill"))
    avatar.tintColor = .systemRed; avatar.contentMode = .scaleAspectFill; avatar.clipsToBounds = true; avatar.layer.cornerRadius = 22
    avatar.widthAnchor.constraint(equalToConstant: 44).isActive = true; avatar.heightAnchor.constraint(equalToConstant: 44).isActive = true
    row.addArrangedSubview(avatar)
    let words = UIStackView(); words.axis = .vertical; words.spacing = 5
    words.addArrangedSubview(text(content.title, size: 17, bold: true))
    words.addArrangedSubview(text(content.body, size: 14, color: .darkGray))
    if let count = Int(data["count"] as? String ?? ""), count > 1, style.hasPrefix("CHAT") {
      words.addArrangedSubview(text(label("\(count) yeni mesaj", "\(count) new messages", "\(count) رسائل جديدة"), size: 11, bold: true, color: .systemRed))
    }
    row.addArrangedSubview(words); stack.addArrangedSubview(row)
    for attachment in content.attachments {
      let accessed = attachment.url.startAccessingSecurityScopedResource()
      defer { if accessed { attachment.url.stopAccessingSecurityScopedResource() } }
      guard let image = UIImage(contentsOfFile: attachment.url.path) else { continue }
      if attachment.identifier == "avatar" { avatar.image = image }
      if attachment.identifier == "photo" {
        let preview = UIImageView(image: image); preview.contentMode = .scaleAspectFill
        preview.clipsToBounds = true; preview.layer.cornerRadius = 12
        preview.heightAnchor.constraint(equalToConstant: 132).isActive = true
        stack.addArrangedSubview(preview)
      }
    }
    view.setNeedsLayout(); view.layoutIfNeeded()
    let width = view.bounds.width > 0 ? view.bounds.width - 32 : 340
    let size = stack.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
    preferredContentSize = CGSize(width: width + 32, height: min(450, max(140, size.height + 28)))
  }
}
