import UIKit
import UserNotifications
import UserNotificationsUI

/// Genisletilmis push icerigi (UNNotificationContentExtension). Tasarim: bildirim-ekranlari (beyaz kart,
/// "BU Kampus · kaynak" ust satiri, kategori karosu/avatar, rozet + cipler, kritik serit, kucuk resim).
/// Kategori `BU_<style>` ile gelir (sunucu APNs `aps.category`; yoksa NotificationService duzeltir).
/// Yalniz yukte GERCEKTEN bulunan alanlar cizilir (sourceName, badgeText, important, severity, eventStartsAt,
/// location, oldStartsAt/newStartsAt, totalKcal, count); eksik alan icin hicbir sey uydurulmaz.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
  private let stack = UIStackView()
  private let criticalBar = UIView()
  private let brand = UIColor(red: 0.776, green: 0.165, blue: 0.125, alpha: 1)
  private let navy = UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor(white: 0.96, alpha: 1) : UIColor(red: 0.09, green: 0.12, blue: 0.20, alpha: 1)
  }
  private let paper = UIColor { traits in
    traits.userInterfaceStyle == .dark ? UIColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1) : UIColor.white
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = paper
    criticalBar.backgroundColor = brand
    criticalBar.isHidden = true
    criticalBar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(criticalBar)
    stack.axis = .vertical; stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      criticalBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      criticalBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      criticalBar.topAnchor.constraint(equalTo: view.topAnchor),
      criticalBar.heightAnchor.constraint(equalToConstant: 4),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -14)
    ])
  }

  // MARK: - Yardimcilar

  private func text(_ value: String, size: CGFloat, bold: Bool = false, color: UIColor? = nil) -> UILabel {
    let label = UILabel(); label.text = value; label.numberOfLines = 0
    label.font = bold ? .systemFont(ofSize: size) : .systemFont(ofSize: size)
    label.textColor = color ?? navy; return label
  }

  private func fixedSize(_ view: UIView, _ width: CGFloat, _ height: CGFloat) {
    view.translatesAutoresizingMaskIntoConstraints = false
    view.widthAnchor.constraint(equalToConstant: width).isActive = true
    view.heightAnchor.constraint(equalToConstant: height).isActive = true
  }

  private func spacer() -> UIView {
    let view = UIView()
    view.setContentHuggingPriority(.defaultLow, for: .horizontal)
    view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return view
  }

  /// Yuvarlak kose cip (opsiyonel SF Symbol). Sigmazsa metin kisalir.
  private func chip(_ value: String, symbol: String? = nil, tint: UIColor, background: UIColor) -> UIView {
    let label = UILabel(); label.text = value; label.font = .systemFont(ofSize: 11); label.textColor = tint
    label.numberOfLines = 1; label.lineBreakMode = .byTruncatingTail
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    let inner = UIStackView(); inner.axis = .horizontal; inner.spacing = 4; inner.alignment = .center
    if let symbol = symbol, let image = UIImage(systemName: symbol) {
      let icon = UIImageView(image: image); icon.tintColor = tint; icon.contentMode = .scaleAspectFit
      fixedSize(icon, 12, 12)
      inner.addArrangedSubview(icon)
    }
    inner.addArrangedSubview(label)
    let box = UIView(); box.backgroundColor = background; box.layer.cornerRadius = 11
    box.setContentHuggingPriority(.required, for: .horizontal)
    inner.translatesAutoresizingMaskIntoConstraints = false
    box.addSubview(inner)
    NSLayoutConstraint.activate([
      inner.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 8),
      inner.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -8),
      inner.topAnchor.constraint(equalTo: box.topAnchor, constant: 4),
      inner.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -4)
    ])
    return box
  }

  private func value(_ key: String, in data: [AnyHashable: Any]) -> String? {
    guard let raw = data[key] else { return nil }
    let string = (raw as? String) ?? ((raw as? NSNumber)?.stringValue ?? "")
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func isTrue(_ raw: String?) -> Bool {
    guard let raw = raw?.lowercased() else { return false }
    return raw == "1" || raw == "true" || raw == "yes"
  }

  private func parseDate(_ raw: String?) -> Date? {
    guard let raw = raw, !raw.isEmpty else { return nil }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: raw) { return date }
    iso.formatOptions = [.withInternetDateTime]
    if let date = iso.date(from: raw) { return date }
    if let number = Double(raw) { return Date(timeIntervalSince1970: number > 100_000_000_000 ? number / 1000 : number) }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
    for pattern in ["yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm"] {
      formatter.dateFormat = pattern
      if let date = formatter.date(from: raw) { return date }
    }
    return nil
  }

  private var istanbul: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
    return calendar
  }

  private func clock(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = istanbul.timeZone
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
  }

  /// "Bugun 14:00" / "Yarin 14:00" / "5 Kas 14:00".
  private func dayAndClock(_ date: Date, code: String, tr: String, en: String, ar: String, trTomorrow: String, enTomorrow: String, arTomorrow: String) -> String {
    let calendar = istanbul
    let now = Date()
    if calendar.isDate(date, inSameDayAs: now) { return (code == "ar" ? ar : code == "en" ? en : tr) + " " + clock(date) }
    if let next = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: next) {
      return (code == "ar" ? arTomorrow : code == "en" ? enTomorrow : trTomorrow) + " " + clock(date)
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: code)
    formatter.timeZone = calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate("d MMM")
    return formatter.string(from: date) + " " + clock(date)
  }

  private func relativeTime(_ date: Date, code: String) -> String {
    let seconds = Date().timeIntervalSince(date)
    if seconds < 60 { return code == "ar" ? "الآن" : code == "en" ? "now" : "şimdi" }
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: code)
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  /// Stil -> SF Symbol + vurgu rengi (kategori karosu; avatar yoksa).
  private func appearance(_ style: String) -> (symbol: String, tint: UIColor) {
    switch style {
    case "CHAT_DIRECT", "CHAT_GROUP", "CHAT_MEDIA": return ("bubble.left.fill", .systemBlue)
    case "EVENT_REMINDER", "EVENT_UPDATE", "EVENT_ADMISSION": return ("calendar", .systemBlue)
    case "EVENT_CANCELLED": return ("calendar.badge.exclamationmark", brand)
    case "MODERATION": return ("exclamationmark.triangle.fill", .systemOrange)
    case "SYSTEM": return ("gearshape.fill", .systemGray)
    case "EXAM", "ACADEMIC": return ("graduationcap.fill", .systemPurple)
    case "ANNOUNCEMENT": return ("megaphone.fill", brand)
    case "POLL": return ("chart.bar.fill", .systemBlue)
    case "MEAL": return ("fork.knife", .systemOrange)
    case "SOCIAL", "LIKE", "FOLLOW", "FOLLOW_REQUEST", "FOLLOW_ACCEPTED": return ("person.fill", .systemGray)
    case "SECURITY": return ("shield.fill", brand)
    case "SUPPORT": return ("lifepreserver", .systemIndigo)
    default: return ("bell.fill", brand)
    }
  }

  private func badgeView(symbol: String?, text badgeText: String?, color: UIColor) -> UIView {
    let badge = UIView(); badge.backgroundColor = color; badge.layer.cornerRadius = 10
    badge.layer.borderWidth = 2; badge.layer.borderColor = paper.resolvedColor(with: traitCollection).cgColor
    fixedSize(badge, 20, 20)
    if let badgeText = badgeText {
      let label = UILabel(); label.text = badgeText; label.font = .systemFont(ofSize: 10); label.textColor = .white
      label.textAlignment = .center; label.translatesAutoresizingMaskIntoConstraints = false
      badge.addSubview(label)
      NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: badge.centerXAnchor), label.centerYAnchor.constraint(equalTo: badge.centerYAnchor)])
    } else if let symbol = symbol, let image = UIImage(systemName: symbol) {
      let icon = UIImageView(image: image); icon.tintColor = .white; icon.contentMode = .scaleAspectFit
      icon.translatesAutoresizingMaskIntoConstraints = false
      badge.addSubview(icon)
      NSLayoutConstraint.activate([
        icon.centerXAnchor.constraint(equalTo: badge.centerXAnchor), icon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        icon.widthAnchor.constraint(equalToConstant: 10), icon.heightAnchor.constraint(equalToConstant: 10)
      ])
    }
    return badge
  }

  /// Avatar (yuvarlak) ya da kategori karosu; sohbette sayi rozeti, sosyalde kalp/kisi/kilit/onay rozeti.
  private func makeTile(style: String, avatar: UIImage?, count: Int) -> UIView {
    let tile = UIView(); fixedSize(tile, 48, 48)
    let base = UIImageView(); base.translatesAutoresizingMaskIntoConstraints = false
    base.clipsToBounds = true; base.contentMode = .scaleAspectFill
    tile.addSubview(base)
    NSLayoutConstraint.activate([
      base.leadingAnchor.constraint(equalTo: tile.leadingAnchor), base.topAnchor.constraint(equalTo: tile.topAnchor),
      base.widthAnchor.constraint(equalToConstant: 44), base.heightAnchor.constraint(equalToConstant: 44)
    ])
    let look = appearance(style)
    if let avatar = avatar {
      base.image = avatar; base.layer.cornerRadius = 22
    } else {
      base.backgroundColor = look.tint.withAlphaComponent(0.14); base.layer.cornerRadius = 14
      if let image = UIImage(systemName: look.symbol) {
        let icon = UIImageView(image: image); icon.tintColor = look.tint; icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        base.addSubview(icon)
        NSLayoutConstraint.activate([
          icon.centerXAnchor.constraint(equalTo: base.centerXAnchor), icon.centerYAnchor.constraint(equalTo: base.centerYAnchor),
          icon.widthAnchor.constraint(equalToConstant: 22), icon.heightAnchor.constraint(equalToConstant: 22)
        ])
      }
    }
    var badge: UIView?
    if style.hasPrefix("CHAT"), count > 1 {
      badge = badgeView(symbol: nil, text: count > 9 ? "9+" : String(count), color: brand)
    } else if style == "LIKE" {
      badge = badgeView(symbol: "heart.fill", text: nil, color: brand)
    } else if style == "FOLLOW" {
      badge = badgeView(symbol: "person.badge.plus", text: nil, color: UIColor(red: 0.09, green: 0.12, blue: 0.20, alpha: 1))
    } else if style == "FOLLOW_REQUEST" {
      badge = badgeView(symbol: "lock.fill", text: nil, color: UIColor(red: 0.09, green: 0.12, blue: 0.20, alpha: 1))
    } else if style == "FOLLOW_ACCEPTED" {
      badge = badgeView(symbol: "checkmark", text: nil, color: .systemGreen)
    }
    if let badge = badge {
      badge.translatesAutoresizingMaskIntoConstraints = false
      tile.addSubview(badge)
      NSLayoutConstraint.activate([
        badge.trailingAnchor.constraint(equalTo: tile.trailingAnchor), badge.bottomAnchor.constraint(equalTo: tile.bottomAnchor),
        badge.widthAnchor.constraint(equalToConstant: 20), badge.heightAnchor.constraint(equalToConstant: 20)
      ])
    }
    return tile
  }

  private func applyDirection(_ view: UIView, _ attribute: UISemanticContentAttribute) {
    view.semanticContentAttribute = attribute
    for child in view.subviews { applyDirection(child, attribute) }
  }

  // MARK: - Cizim

  func didReceive(_ notification: UNNotification) {
    loadViewIfNeeded()
    stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    let content = notification.request.content
    let data = content.userInfo
    let style = content.categoryIdentifier.replacingOccurrences(of: "BU_", with: "")
    let locale = (data["locale"] as? String) ?? Locale.preferredLanguages.first ?? "tr"
    let code = locale.hasPrefix("ar") ? "ar" : locale.hasPrefix("en") ? "en" : "tr"
    func label(_ tr: String, _ en: String, _ ar: String) -> String { code == "ar" ? ar : code == "en" ? en : tr }

    let critical = value("severity", in: data)?.lowercased() == "critical"
    criticalBar.isHidden = !critical
    let important = isTrue(value("important", in: data))
    let badgeText = value("badgeText", in: data)

    // Kaynak etiketi: sunucu `sourceName` (kulup/birim adi) > stile gore varsayilan.
    var section: String?
    switch style {
    case "CHAT_DIRECT": section = label("Sohbet", "Chat", "محادثة")
    case "CHAT_GROUP": section = label("Kulüp Odası", "Group chat", "محادثة جماعية")
    case "CHAT_MEDIA": section = label("Medya", "Media", "وسائط")
    case "EVENT_REMINDER", "EVENT_UPDATE", "EVENT_ADMISSION", "EVENT_CANCELLED": section = label("Etkinlik", "Event", "فعالية")
    case "EXAM", "ACADEMIC": section = label("Akademik", "Academic", "أكاديمي")
    case "ANNOUNCEMENT": section = label("Duyuru", "Announcement", "إعلان")
    case "POLL": section = label("Anket", "Poll", "استطلاع")
    case "MEAL": section = label("Bugünün Menüsü", "Today's menu", "قائمة اليوم")
    case "SECURITY": section = label("Güvenlik", "Security", "الأمان")
    case "SUPPORT": section = label("Destek Masası", "Support", "الدعم")
    case "MODERATION": section = label("Moderasyon", "Moderation", "الإشراف")
    case "SYSTEM": section = label("Sistem", "System", "النظام")
    case "SOCIAL", "LIKE", "FOLLOW", "FOLLOW_REQUEST", "FOLLOW_ACCEPTED": section = nil
    default: section = label("Bildirim", "Notification", "إشعار")
    }
    let source = value("sourceName", in: data) ?? section

    // Gorselleri once topla (avatar / foto).
    var avatarImage: UIImage?
    var photoImage: UIImage?
    for attachment in content.attachments {
      let accessed = attachment.url.startAccessingSecurityScopedResource()
      defer { if accessed { attachment.url.stopAccessingSecurityScopedResource() } }
      guard let image = UIImage(contentsOfFile: attachment.url.path) else { continue }
      if attachment.identifier == "avatar" { avatarImage = image }
      if attachment.identifier == "photo" { photoImage = image }
    }

    // 1) Ust satir: BU logosu, "BU Kampüs", kaynak, (onemli), zaman
    let header = UIStackView(); header.axis = .horizontal; header.alignment = .center; header.spacing = 6
    let logo = UILabel(); logo.text = "BU"; logo.font = .systemFont(ofSize: 9); logo.textColor = .white
    logo.textAlignment = .center; logo.backgroundColor = brand; logo.layer.cornerRadius = 11; logo.clipsToBounds = true
    fixedSize(logo, 22, 22)
    header.addArrangedSubview(logo)
    header.addArrangedSubview(text("BU Kampüs", size: 13, bold: true))
    if important {
      header.addArrangedSubview(text("• " + (badgeText ?? label("ÖNEMLİ", "IMPORTANT", "مهم")), size: 11, bold: true, color: brand))
    } else if let source = source {
      let sourceLabel = text("· " + source, size: 12, color: critical ? brand : .secondaryLabel)
      if critical { sourceLabel.font = .systemFont(ofSize: 12) }
      sourceLabel.numberOfLines = 1; sourceLabel.lineBreakMode = .byTruncatingTail
      sourceLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      header.addArrangedSubview(sourceLabel)
    }
    header.addArrangedSubview(spacer())
    let time = text(relativeTime(notification.date, code: code), size: 12, color: .secondaryLabel)
    time.numberOfLines = 1; time.setContentHuggingPriority(.required, for: .horizontal)
    header.addArrangedSubview(time)
    stack.addArrangedSubview(header)

    // 2) Govde: avatar/karo + baslik/govde + (kucuk resim)
    let count = Int(value("count", in: data) ?? "") ?? 0
    let row = UIStackView(); row.axis = .horizontal; row.alignment = .top; row.spacing = 12
    row.addArrangedSubview(makeTile(style: style, avatar: avatarImage, count: count))

    let words = UIStackView(); words.axis = .vertical; words.spacing = 5
    let titleRow = UIStackView(); titleRow.axis = .horizontal; titleRow.alignment = .center; titleRow.spacing = 6
    let titleText = style == "CHAT_GROUP" ? (value("conversationTitle", in: data) ?? content.title) : content.title
    let title = text(titleText, size: 17, bold: true)
    title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    titleRow.addArrangedSubview(title)
    if style == "CHAT_GROUP", let sender = value("senderName", in: data), sender != titleText {
      let senderLabel = text("· " + sender, size: 12, bold: true, color: .secondaryLabel)
      senderLabel.numberOfLines = 1; senderLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      titleRow.addArrangedSubview(senderLabel)
    }
    if style == "CHAT_DIRECT" {
      let dm = text("DM", size: 11, bold: true, color: brand); dm.numberOfLines = 1
      dm.setContentHuggingPriority(.required, for: .horizontal)
      titleRow.addArrangedSubview(dm)
    }
    if style.hasPrefix("CHAT"), count > 1 {
      titleRow.addArrangedSubview(chip(label("\(count) yeni mesaj", "\(count) new messages", "\(count) رسائل جديدة"),
        tint: brand, background: brand.withAlphaComponent(0.12)))
    } else if !important, let badgeText = badgeText {
      titleRow.addArrangedSubview(chip(badgeText, tint: brand, background: brand.withAlphaComponent(0.12)))
    }
    if titleRow.arrangedSubviews.count > 1 { titleRow.addArrangedSubview(spacer()) }
    words.addArrangedSubview(titleRow)

    // Etkinlik saat revizesi: yeni saat kalin + eski saat ustu cizili (yalniz iki alan da varsa)
    if let newDate = parseDate(value("newStartsAt", in: data)), let oldDate = parseDate(value("oldStartsAt", in: data)) {
      let line = NSMutableAttributedString(string: label("Yeni saat: ", "New time: ", "الوقت الجديد: "),
        attributes: [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.secondaryLabel])
      line.append(NSAttributedString(string: clock(newDate), attributes: [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: navy]))
      line.append(NSAttributedString(string: "  (" + label("Eski saat: ", "Old time: ", "الوقت السابق: ") + clock(oldDate) + ")",
        attributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.secondaryLabel,
                     .strikethroughStyle: NSUnderlineStyle.single.rawValue]))
      let revision = UILabel(); revision.attributedText = line; revision.numberOfLines = 0
      words.addArrangedSubview(revision)
    }

    let body = text(content.body, size: 14, color: .secondaryLabel)
    body.numberOfLines = 5
    words.addArrangedSubview(body)

    // 3) Cipler: etkinlik/sinav zamani + yer, yemek kalorisi (yalniz yukte varsa)
    let chips = UIStackView(); chips.axis = .horizontal; chips.alignment = .center; chips.spacing = 6
    let startRaw = value("eventStartsAt", in: data) ?? value("newStartsAt", in: data)
    if style.hasPrefix("EVENT") || style == "EXAM", let start = parseDate(startRaw) {
      var textValue = dayAndClock(start, code: code, tr: "Bugün", en: "Today", ar: "اليوم", trTomorrow: "Yarın", enTomorrow: "Tomorrow", arTomorrow: "غدًا")
      if let place = value("location", in: data) { textValue += " · " + place }
      chips.addArrangedSubview(chip(textValue, symbol: "calendar", tint: brand, background: brand.withAlphaComponent(0.12)))
    }
    if style == "MEAL", let kcal = value("totalKcal", in: data), Int(kcal) != nil,
       value("kcalComplete", in: data).map({ isTrue($0) }) ?? true {
      chips.addArrangedSubview(chip(label("Toplam \(kcal) kcal", "Total \(kcal) kcal", "المجموع \(kcal) سعرة"),
        symbol: "flame.fill", tint: .systemGreen, background: UIColor.systemGreen.withAlphaComponent(0.14)))
    }
    if !chips.arrangedSubviews.isEmpty {
      chips.addArrangedSubview(spacer())
      words.addArrangedSubview(chips)
    }
    row.addArrangedSubview(words)

    // Kucuk resim sagda (haber/gonderi/menu); sohbet fotografi asagida genis onizleme
    if let photo = photoImage, style != "CHAT_MEDIA" {
      let thumb = UIImageView(image: photo); thumb.contentMode = .scaleAspectFill
      thumb.clipsToBounds = true; thumb.layer.cornerRadius = 12
      fixedSize(thumb, 64, 64)
      row.addArrangedSubview(thumb)
    }
    stack.addArrangedSubview(row)
    if let photo = photoImage, style == "CHAT_MEDIA" {
      let preview = UIImageView(image: photo); preview.contentMode = .scaleAspectFill
      preview.clipsToBounds = true; preview.layer.cornerRadius = 12
      preview.heightAnchor.constraint(equalToConstant: 132).isActive = true
      stack.addArrangedSubview(preview)
    }

    applyDirection(stack, code == "ar" ? .forceRightToLeft : .forceLeftToRight)

    view.setNeedsLayout(); view.layoutIfNeeded()
    let width = view.bounds.width > 0 ? view.bounds.width - 32 : 340
    let size = stack.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
    preferredContentSize = CGSize(width: width + 32, height: min(450, max(140, size.height + 30)))
  }
}
