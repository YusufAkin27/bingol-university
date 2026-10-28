/// Android bildirim kanalı tablosu. Kimlikler SUNUCU sözleşmesiyle aynıdır
/// (`PushMessages.channel`: chat / event / announcement) ve `LocalReminders.kt` içindeki
/// `Channels.ensure` ile eşleşmelidir. `social`/`poll` şimdilik sunucu tarafından kullanılmaz
/// (beğeni/takip `announcement` kanalına düşer); ileride sunucu geçince hazır dursun diye tabloda var.
enum PushImportance { low, defaultLevel, high }

class PushChannel {
  const PushChannel(this.id, this.importance, this.l10nKey);
  final String id;
  final PushImportance importance;

  /// Kanal adı l10n anahtarı (ARB: `bildirimmobilKanal...`).
  final String l10nKey;
}

const pushChannels = <PushChannel>[
  PushChannel('chat', PushImportance.high, 'chat'),
  PushChannel('event', PushImportance.defaultLevel, 'event'),
  PushChannel('announcement', PushImportance.defaultLevel, 'announcement'),
  PushChannel('social', PushImportance.low, 'social'),
  PushChannel('poll', PushImportance.defaultLevel, 'poll'),
  PushChannel('academic', PushImportance.high, 'academic'),
];

/// Bildirim türü (`type`) -> sunucunun seçtiği kanal (yedek eşleme; istemci yerel şerit için kullanır).
String channelForType(String? type) {
  switch ((type ?? '').toUpperCase()) {
    case 'MESSAGE':
      return 'chat';
    case 'EVENT':
      return 'event';
    default:
      return 'announcement';
  }
}
