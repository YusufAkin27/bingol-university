// Yönetim paneli Sistem sağlığı sayfaları (sistem1): trafik ışığı, ana göstergeler, çizelge, büyüme, yedek tazeliği, çökme dağılımı.
// Yönetim paneli YALNIZ Türkçedir: en/ar karşılığı yazılmaz. Sözlük i18n/tr altında değil sayfa klasöründedir (paylaşılan
// check-i18n muaf listesine dokunmamak için); sayfalar bunu kendi tembel parçalarında registerExtraEntries ile kaydeder (dict.ts).
export default {
  // trafik ışığı
  'admin.s1.light.aria': 'Genel durum: {state}',
  'admin.s1.light.good': 'İyi',
  'admin.s1.light.attention': 'Dikkat',
  'admin.s1.light.urgent': 'Acil',
  'admin.s1.light.unknown': 'Bilinmiyor',

  // Sistem durumu: dört ana gösterge
  'admin.s1.gauge.title': 'Dört ana gösterge',
  'admin.s1.gauge.storage': 'Depolama',
  'admin.s1.gauge.storage.ring': 'dolu',
  'admin.s1.gauge.storage.ok': 'Disklerde yeterli boş yer var.',
  'admin.s1.gauge.storage.bad': 'En dolu disk {value}. Eski kayıtları dışa aktarıp temizlemek gerekebilir.',
  'admin.s1.gauge.storage.go': 'Veri saklama sayfasına git',
  'admin.s1.gauge.backup': 'Yedek tazeliği',
  'admin.s1.gauge.backup.aria': 'Son başarılı yedek: {value}. Yeşil bölge güncel, sarı gecikmiş, kırmızı çok eski.',
  'admin.s1.gauge.backup.ok': 'Yedekler düzenli alınıyor.',
  'admin.s1.gauge.backup.bad': 'Yedek gecikmiş olabilir; Yedekleme sayfasına bakın.',
  'admin.s1.gauge.backup.drive': 'Google Drive kopyası: {value}.',
  'admin.s1.gauge.backup.unknown': 'Yedek bilgisi alınamadı.',
  'admin.s1.gauge.backup.go': 'Yedekleme sayfasına git',
  'admin.s1.gauge.queues': 'Gönderim sıraları',
  'admin.s1.gauge.queues.ok': 'E-posta ve bildirimler takılmadan gidiyor.',
  'admin.s1.gauge.queues.bad': 'Bazı gönderimler bekliyor ya da gönderilemedi; aşağıdaki kayıtlara bakın.',
  'admin.s1.gauge.jobs': 'Otomatik görevler',
  'admin.s1.gauge.jobs.ring': 'zamanında çalıştı',
  'admin.s1.gauge.jobs.ok': '{n} görevin hepsi zamanında çalıştı.',
  'admin.s1.gauge.jobs.bad': '{n} görevin {bad} tanesi geç kaldı ya da hiç çalışmadı.',

  // sağlık çizelgesi
  'admin.s1.timeline.title': 'Sağlık çizelgesi',
  'admin.s1.timeline.aria': 'Son kontroller: yüksek çubuk daha ciddi durum demektir',
  'admin.s1.timeline.few': 'Şimdilik tek kontrol var. Sayfa açık kaldıkça çizelge dolar (30 saniyede bir kontrol edilir).',
  'admin.s1.timeline.allGood': 'Son {n} kontrolün hepsi iyi çıktı.',
  'admin.s1.timeline.someBad': 'Son {n} kontrolün {bad} tanesinde dikkat gerektiren bir durum vardı; en sonuncusu {time} sıralarında.',
  'admin.s1.timeline.note': 'Çizelge bu tarayıcıda, bu oturum boyunca yapılan kontrollerden oluşur; sunucu geçmiş tutmaz.',

  // görev şeridi
  'admin.s1.jobs.title': 'Otomatik görevler ne zaman çalıştı?',
  'admin.s1.jobs.ok': '{n} görevin hepsi zamanında çalıştı.',
  'admin.s1.jobs.bad': '{n} görevin {bad} tanesi geç kaldı; sorunlular listenin başında.',
  'admin.s1.jobs.aria': '{name}: {when}. Yeşil bölge zamanında, sarı gecikmiş, kırmızı çok geç.',
  'admin.s1.jobs.note': 'İşaret soldan sağa görevin son çalışmasından bu yana geçen süreyi gösterir; ne kadar sağdaysa o kadar geç kalmıştır.',

  // Operasyon
  'admin.s1.ops.title': 'Operasyon özeti',
  'admin.s1.ops.ok': 'Her şey yolunda: sistem parçaları çalışıyor, gönderim sırası temiz, yedek güncel.',
  'admin.s1.ops.bad': 'Dikkat edilecekler:',
  'admin.s1.ops.none': 'Durum bilgisi alınamadı; sekmelerdeki kartlara bakın.',
  'admin.s1.ops.more': 'Tüm göstergeler için',
  'admin.s1.ops.moreLink': 'Sistem durumu sayfasına bakın.',
  'admin.s1.ops.p.health': 'bir sistem parçası sorunlu',
  'admin.s1.ops.p.queues': '{n} e-posta/bildirim gönderilemedi',
  'admin.s1.ops.p.backupFailed': 'son yedek alınamadı',
  'admin.s1.ops.p.backupNever': 'henüz başarılı yedek yok',
  'admin.s1.ops.p.backupStale': 'son yedek {h} saat önce',
  'admin.s1.ops.diskRing': 'dolu',
  'admin.s1.ops.queueBar': 'Sıradaki işlerin dağılımı',
  'admin.s1.ops.numbers': 'Ayrıntılı sayılar',
  'admin.s1.ops.backupAgo': 'Son başarılı yedek yaklaşık {h} saat önce alındı.',
  'admin.s1.ops.backupGauge': 'Son yedek {h} saat önce. Yeşil bölge güncel, sarı gecikmiş, kırmızı çok eski.',

  // Veri saklama
  'admin.s1.storage.ring': 'dolu',
  'admin.s1.storage.ok': 'Depolama rahat: en dolu disk %{pct} dolu, uyarı %{warn} dolunca verilir.',
  'admin.s1.storage.bad': 'Depolama doluyor: en dolu disk %{pct} (uyarı %{warn}, acil %{crit}). Eski kayıtları dışa aktarıp temizleyin.',
  'admin.s1.storage.unknown': 'Doluluk ölçülemedi; disk bilgisi sunucudan gelmedi.',
  'admin.s1.storage.top': 'Veritabanında en çok yer tutan tablolar',
  'admin.s1.storage.topEmpty': 'Tablo boyutu bilgisi yok.',
  'admin.s1.storage.details': 'Disk ve veritabanı ayrıntıları',
  'admin.s1.growth.title': 'Hangi kayıtlar ne kadar hızlı büyüyor?',
  'admin.s1.growth.subject': 'Büyüme tahmini',
  'admin.s1.growth.none': 'Tahmin için yeterli veri yok: tabloların en az bir günlük geçmişi olmalı.',
  'admin.s1.growth.withDays': 'En hızlı büyüyen: {name}, günde ortalama {perDay}. Bu hızla büyürse veritabanı diskindeki boş yer yaklaşık {days} gün yeter.',
  'admin.s1.growth.noDays': 'En hızlı büyüyen: {name}, günde ortalama {perDay}. Boş yer bilgisi olmadığından "kaç gün yeter" hesaplanamadı.',
  'admin.s1.growth.aria': 'Tabloların günlük ortalama büyümesi',
  'admin.s1.growth.perDay': 'günde {size}',
  'admin.s1.growth.note': 'Bu bir tahmindir: tablonun şimdiki boyutu, en eski kaydından bu yana geçen güne bölünür. Temizlik yapıldıysa gerçek büyüme daha yüksektir.',

  // Yedekleme
  'admin.s1.backup.title': 'Yedekler güvende mi?',
  'admin.s1.backup.none': 'Henüz başarılı bir yedek görünmüyor.',
  'admin.s1.backup.fresh.FRESH': 'Son yedek {ago} alındı: yedekler güncel.',
  'admin.s1.backup.fresh.STALE': 'Son yedek {ago} alındı: biraz gecikmiş, saatlik yedeğin çalışıp çalışmadığına bakın.',
  'admin.s1.backup.fresh.OLD': 'Son yedek {ago} alındı: çok eski, acilen kontrol edin.',
  'admin.s1.backup.fresh.FAILED': 'Son yedekleme denemesi başarısız oldu ({ago} alınan yedek en son başarılı olandır).',
  'admin.s1.backup.gauge': 'Son yedek {ago}. Yeşil bölge güncel, sarı gecikmiş, kırmızı çok eski; ölçek 48 saattir.',
  'admin.s1.backup.counts': 'Sunucudaki ve Google Drive’daki yedek sayısı',
  'admin.s1.backup.local': 'Sunucuda',
  'admin.s1.backup.remote': 'Google Drive’da',
  'admin.s1.backup.countValue': '{n} yedek',
  'admin.s1.backup.scaleNote': 'Yedek saatlik alınır; 3 saatten eskisi gecikmiş, 24 saatten eskisi çok eski sayılır.',
  'admin.s1.backup.details': 'Ayrıntılı kartlar',

  // Çökme raporları
  'admin.s1.crash.title': 'Çökme özeti',
  'admin.s1.crash.statusTitle': 'Çökmeler hangi durumda?',
  'admin.s1.crash.statusAria': 'Çökme gruplarının durum dağılımı',
  'admin.s1.crash.status.NEW': 'Yeni',
  'admin.s1.crash.status.ACK': 'İncelemede',
  'admin.s1.crash.status.RESOLVED': 'Çözüldü',
  'admin.s1.crash.statusNote': 'Aynı hatanın tekrarları tek grupta toplanır; çubuk grupları sayar, tek tek raporları değil.',
  'admin.s1.crash.noGroups': 'Henüz çökme grubu yok.',
  'admin.s1.crash.versionTitle': 'Hangi sürümde kaç çökme?',
  'admin.s1.crash.versionSentence': 'En çok çöken: {platform} {version} sürümü ({n} kez).',
  'admin.s1.crash.versionNote': 'En çok çöken ilk 50 hata grubuna göre hesaplanır. Yeni bir sürüm çıktıktan sonra eski sürümün azalması beklenir.',
  'admin.s1.crash.noVersions': 'Sürüm dağılımı için yeterli çökme raporu yok.',
  'admin.s1.crash.times': '{n} kez',

  // Şifreleme
  'admin.s1.crypto.ring': 'güncel anahtarla korunuyor',
  'admin.s1.crypto.technical': 'Teknik ayrıntı: anahtar kimlikleri ve sayıları',

  // teknik bölüm
  'admin.s1.tech.title': 'Teknik ayrıntılar ({n} gösterge)',
  'admin.s1.tech.hint': 'Tek tek göstergeler, eşikler ve açıklamalar. Sorun yoksa bakmanız gerekmez.',
}
