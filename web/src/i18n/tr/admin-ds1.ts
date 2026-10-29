// Yönetim paneli Veri saklama (DS1): depolama doluluğu, log tablosu dışa aktarma ve onaylı temizlik.
// Yönetim paneli YALNIZ Türkçedir: bu dosyanın en/ar karşılığı yazılmaz; i18n/bundles/admin-tr-only.ts en/ar
// sözlüklerine aynı Türkçe metni katar ve scripts/check-i18n.mjs bu dosyayı en/ar eşitliği denetiminden muaf tutar.
export default {
  'admin.ds1.nav': 'Veri saklama',
  'admin.ds1.title': 'Veri saklama ve depolama',
  'admin.ds1.desc':
    'Şişen log kayıtlarını makbuzlu olarak dışarı aktarın, yedeğiniz güvendeyse eski kayıtları temizleyin ve depolama doluluğunu izleyin.',

  // uyarı bandı (tüm yönetim sayfalarında)
  'admin.ds1.banner.warn': 'Depolama alanı %{pct} doldu (uyarı eşiği %{warn}).',
  'admin.ds1.banner.crit': 'Depolama alanı kritik: %{pct} dolu (kritik eşik %{crit}).',
  'admin.ds1.banner.action': 'Veri saklama sayfasından eski kayıtları dışa aktarıp temizleyin.',
  'admin.ds1.banner.link': 'Veri saklama sayfasına git',

  // doluluk kartları
  'admin.ds1.storage.title': 'Depolama doluluğu',
  'admin.ds1.storage.updated': 'Son ölçüm: {time}',
  'admin.ds1.storage.alert.warn': 'Depolama alanı %{pct} doldu. Eşik: uyarı %{warn}, kritik %{crit}.',
  'admin.ds1.storage.alert.crit': 'Depolama alanı kritik seviyede: %{pct} dolu. Eşik: uyarı %{warn}, kritik %{crit}.',
  'admin.ds1.storage.alert.hint':
    'Aşağıdaki tablolardan en büyük olanları dışa aktarıp (makbuz alın) ardından eski kayıtları temizleyin.',
  'admin.ds1.storage.db.size': 'Veritabanı boyutu',
  'admin.ds1.storage.db.unknown': 'Ölçülemedi',
  'admin.ds1.storage.db.top': 'En büyük tablolar',
  'admin.ds1.storage.dbDisk': 'Veritabanı sunucusu diski',
  'admin.ds1.storage.appDisk': 'Uygulama diski',
  'admin.ds1.storage.role.uploads': 'Yüklemeler',
  'admin.ds1.storage.role.backups': 'Yedekler',
  'admin.ds1.storage.role.app': 'Uygulama',
  'admin.ds1.storage.role.db': 'Veritabanı',
  'admin.ds1.storage.source.MEASURED': 'Ölçülen (disk bölümü)',
  'admin.ds1.storage.source.COMPUTED': 'Kapasite ayarından hesaplanan',
  'admin.ds1.storage.source.UNKNOWN': 'Bilinmiyor',
  'admin.ds1.storage.source.MEASURED.hint': 'Disk bölümünün gerçek doluluğu işletim sisteminden okundu.',
  'admin.ds1.storage.source.COMPUTED.hint':
    'Gerçek disk görülemediği için yüzde, kapasite ayarına göre hesaplandı: veritabanı + yüklemeler + yedekler + sabit pay ÷ kapasite.',
  'admin.ds1.storage.source.UNKNOWN.hint':
    'Veritabanı sunucusunun diski ölçülemiyor. STORAGE_DB_DISK_CAPACITY_BYTES (VPS disk boyutu) veya STORAGE_DB_DISK_PATH ayarlayın.',
  'admin.ds1.storage.used': '{used} / {total} kullanımda',
  'admin.ds1.storage.free': '{free} boş',
  'admin.ds1.storage.level.OK': 'Normal',
  'admin.ds1.storage.level.WARN': 'Uyarı',
  'admin.ds1.storage.level.CRIT': 'Kritik',
  'admin.ds1.storage.level.UNKNOWN': 'Bilinmiyor',
  'admin.ds1.storage.progress': '{name} doluluk yüzdesi',
  'admin.ds1.storage.error': 'Depolama doluluğu okunamadı.',

  // tablo listesi
  'admin.ds1.tables.title': 'Şişebilen log tabloları',
  'admin.ds1.tables.intro':
    'Yalnız log ve kuyruk tabloları listelenir; kullanıcı verisi, mesaj ve sözleşme onayları buradan asla silinemez. Satır sayısı tahmindir.',
  'admin.ds1.tables.col.table': 'Tablo',
  'admin.ds1.tables.col.rows': 'Satır (≈)',
  'admin.ds1.tables.col.size': 'Boyut',
  'admin.ds1.tables.col.oldest': 'En eski kayıt',
  'admin.ds1.tables.col.min': 'Asgari saklama',
  'admin.ds1.tables.col.actions': 'İşlemler',
  'admin.ds1.tables.minDays': '{n} gün',
  'admin.ds1.tables.personal': 'Kişisel veri',
  'admin.ds1.tables.exportOnly': 'Yalnız dışa aktarılır',
  'admin.ds1.tables.export': 'Dışa aktar',
  'admin.ds1.tables.purge': 'Temizle',
  'admin.ds1.tables.readOnlyNote':
    'Dışa aktarma ve temizleme yalnız tam yetkili (FULL) yöneticilere açıktır; bu sayfayı yalnız görüntüleyebilirsiniz.',
  'admin.ds1.tables.empty': 'Listelenecek tablo yok.',
  'admin.ds1.tables.error': 'Tablo listesi okunamadı.',
  'admin.ds1.tables.unknown': '—',

  // dışa aktarma
  'admin.ds1.export.title': 'Dışa aktar: {table}',
  'admin.ds1.export.intro':
    'Seçilen aralıktaki kayıtlar gzip ile sıkıştırılmış CSV olarak indirilir. İndirme bitince bir makbuz (satır sayısı ve SHA-256) oluşur; silme bu makbuza dayanır.',
  'admin.ds1.export.personal': 'Bu dosya kişisel veri içerir. Güvenli bir yerde saklayın ve yetkisiz kişilerle paylaşmayın.',
  'admin.ds1.export.from': 'Başlangıç (dahil, boşsa baştan)',
  'admin.ds1.export.to': 'Bitiş (bu gün hariç)',
  'admin.ds1.export.toHint': 'En geç {max} seçilebilir (asgari saklama {n} gün).',
  'admin.ds1.export.reason': 'Dışa aktarma gerekçesi',
  'admin.ds1.export.start': 'Dışa aktar ve indir',
  'admin.ds1.export.running': 'Dışa aktarılıyor… Sayfayı kapatmayın.',
  'admin.ds1.export.invalidRange': 'Tarih aralığı geçersiz: başlangıç bitişten önce olmalı ve bitiş izin verilen son tarihi aşmamalı.',
  'admin.ds1.export.done': 'Dışa aktarma tamamlandı',
  'admin.ds1.export.partial':
    'Dosya satır üst sınırına ulaştığı için KISMİ. Bu makbuz silmeyi açmaz; aralığı daraltıp yeniden dışa aktarın.',
  'admin.ds1.export.verified': 'İndirilen dosyanın SHA-256 değeri makbuzla eşleşti.',
  'admin.ds1.export.mismatch': 'UYARI: indirilen dosyanın SHA-256 değeri makbuzla eşleşmedi. Dosyayı saklamayın, yeniden dışa aktarın.',
  'admin.ds1.export.goPurge': 'Bu aralığı temizlemeye geç',
  'admin.ds1.export.close': 'Kapat',

  // makbuz
  'admin.ds1.receipt.title': 'Dışa aktarma makbuzu #{id}',
  'admin.ds1.receipt.range': 'Aralık',
  'admin.ds1.receipt.rows': 'Satır',
  'admin.ds1.receipt.bytes': 'Dosya boyutu',
  'admin.ds1.receipt.sha': 'SHA-256',
  'admin.ds1.receipt.admin': 'Yönetici',
  'admin.ds1.receipt.at': 'Zaman',
  'admin.ds1.receipt.status.RUNNING': 'Sürüyor',
  'admin.ds1.receipt.status.COMPLETED': 'Tamamlandı',
  'admin.ds1.receipt.status.PARTIAL': 'Kısmi',
  'admin.ds1.receipt.status.FAILED': 'Başarısız',

  // temizlik
  'admin.ds1.purge.title': 'Temizle: {table}',
  'admin.ds1.purge.intro':
    'Silinen kayıtlar geri getirilemez. Bu işlem yalnız asgari saklama süresinden ({n} gün) eski kayıtları siler ve dışa aktarma makbuzu ister.',
  'admin.ds1.purge.from': 'Başlangıç (dahil, boşsa baştan)',
  'admin.ds1.purge.to': 'Bitiş (bu gün hariç)',
  'admin.ds1.purge.preview.loading': 'Önizleme hazırlanıyor…',
  'admin.ds1.purge.preview.error': 'Önizleme alınamadı.',
  'admin.ds1.purge.preview.rows': 'Silinecek kayıt',
  'admin.ds1.purge.preview.capped': '{n}+ (sayım üst sınırında kesildi)',
  'admin.ds1.purge.preview.bytes': 'Tahmini boyut',
  'admin.ds1.purge.receipt.ok': 'Bu aralık dışa aktarıldı: makbuz #{id} ({rows} satır).',
  'admin.ds1.purge.receipt.none.title': 'Bu aralık için dışa aktarma makbuzu yok — silme kapalı',
  'admin.ds1.purge.receipt.none.body':
    'Önce aralığı dışa aktarın. Makbuz olmadan silmek verinin tek kopyasını kaybetmeniz demektir.',
  'admin.ds1.purge.receipt.stale.title': 'Makbuz eskimiş — silme kapalı',
  'admin.ds1.purge.receipt.stale.body':
    'Makbuzdan sonra bu aralığa yeni kayıtlar eklenmiş. Yeniden dışa aktarın.',
  'admin.ds1.purge.exportFirst': 'Önce dışa aktar',
  'admin.ds1.purge.nothing': 'Bu aralıkta silinecek kayıt yok.',
  'admin.ds1.purge.notDeletable': 'Bu tablo panelden silinemez; yalnız dışa aktarılabilir.',
  'admin.ds1.purge.danger.title': 'Geri alınamaz işlem',
  'admin.ds1.purge.danger.body':
    'Kayıtlar veritabanından kalıcı olarak silinir. Denetim kayıtları silinse bile silme işlemi kim/ne zaman/ne kadar bilgisiyle ayrıca saklanır.',
  'admin.ds1.purge.reason': 'Silme gerekçesi',
  'admin.ds1.purge.force.label': 'Makbuzsuz sil (tehlikeli)',
  'admin.ds1.purge.force.hint':
    'Yedek almadan silmek verinin tek kopyasını yok eder. Yalnız tam yetkili yönetici ve en az 20 karakterlik gerekçeyle yapılabilir.',
  'admin.ds1.purge.confirmTable': 'Onay için tablo adını yazın',
  'admin.ds1.purge.confirmLabel': 'Kalıcı olarak sil',
  'admin.ds1.purge.starting': 'Temizlik başlatılıyor…',
  'admin.ds1.purge.progress': 'Temizlik sürüyor: {deleted} / ≈{est} kayıt silindi',
  'admin.ds1.purge.done': 'Temizlik tamamlandı: {deleted} kayıt silindi.',
  'admin.ds1.purge.failed': 'Temizlik başarısız oldu: {error}',
  'admin.ds1.purge.interrupted': 'Temizlik yarıda kesildi (uygulama yeniden başlamış olabilir). Silinen: {deleted}. Yeniden başlatabilirsiniz.',
  'admin.ds1.purge.vacuum':
    'Disk alanı işletim sistemine hemen dönmeyebilir: PostgreSQL ölü satırları yeniden kullanır. Alanı geri almak için bakım penceresinde VACUUM FULL <tablo> çalıştırın (tabloyu kilitler).',
  'admin.ds1.purge.progress.label': 'Temizlik ilerlemesi',
  'admin.ds1.purge.close': 'Kapat',

  // geçmiş
  'admin.ds1.history.title': 'Geçmiş',
  'admin.ds1.history.tab.receipts': 'Dışa aktarma makbuzları',
  'admin.ds1.history.tab.purges': 'Silme geçmişi',
  'admin.ds1.history.tabs': 'Geçmiş sekmeleri',
  'admin.ds1.history.col.id': 'No',
  'admin.ds1.history.col.table': 'Tablo',
  'admin.ds1.history.col.range': 'Aralık',
  'admin.ds1.history.col.rows': 'Satır',
  'admin.ds1.history.col.size': 'Boyut',
  'admin.ds1.history.col.status': 'Durum',
  'admin.ds1.history.col.admin': 'Yönetici',
  'admin.ds1.history.col.at': 'Zaman',
  'admin.ds1.history.col.reason': 'Gerekçe',
  'admin.ds1.history.col.sha': 'SHA-256',
  'admin.ds1.history.forced': 'Makbuzsuz',
  'admin.ds1.history.receiptRef': 'Makbuz #{id}',
  'admin.ds1.history.emptyReceipts': 'Henüz dışa aktarma yok.',
  'admin.ds1.history.emptyPurges': 'Henüz temizlik yapılmadı.',
  'admin.ds1.history.error': 'Geçmiş okunamadı.',
  'admin.ds1.purgeStatus.RUNNING': 'Sürüyor',
  'admin.ds1.purgeStatus.COMPLETED': 'Tamamlandı',
  'admin.ds1.purgeStatus.FAILED': 'Başarısız',
  'admin.ds1.purgeStatus.INTERRUPTED': 'Kesildi',

  // sunucu hata kodları (admin.err.* yerine bu kapsam kullanılır; bkz. DataRetentionPage)
  'admin.ds1.err.RETENTION_EXPORT_REQUIRED': 'Bu aralık için tamamlanmış bir dışa aktarma makbuzu yok; önce dışa aktarın.',
  'admin.ds1.err.RETENTION_RECEIPT_STALE': 'Aralığa makbuzdan sonra yeni kayıtlar eklenmiş; yeniden dışa aktarın.',
  'admin.ds1.err.RETENTION_RANGE_TOO_RECENT': 'Bitiş tarihi asgari saklama süresinden yeni olamaz.',
  'admin.ds1.err.RETENTION_CONFIRM_MISMATCH': 'Onay için tablo adını aynen yazın.',
  'admin.ds1.err.RETENTION_PURGE_RUNNING': 'Başka bir temizlik sürüyor; bitmesini bekleyin.',
  'admin.ds1.err.RETENTION_EXPORT_BUSY': 'Başka dışa aktarmalar sürüyor; birazdan tekrar deneyin.',
  'admin.ds1.err.RETENTION_FORCE_FORBIDDEN': 'Makbuzsuz silme yalnız tam yetkili (FULL) yöneticiye açıktır.',
  'admin.ds1.err.RETENTION_NOTHING_TO_DELETE': 'Bu aralıkta silinecek kayıt yok.',
  'admin.ds1.err.RETENTION_TABLE_NOT_DELETABLE': 'Bu tablo panelden silinemez; yalnız dışa aktarılabilir.',
};
