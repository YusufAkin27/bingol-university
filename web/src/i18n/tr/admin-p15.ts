// Yönetim paneli toplu işlemler ve dışa aktarma (P15): haber, akademik, menü, bekleyen kayıt; kaynak durumu sayfası.
// Yönetim paneli YALNIZ Türkçedir: bu dosyanın en/ar karşılığı yazılmaz; i18n/index.ts en/ar sözlüklerine aynı Türkçe
// metni katar ve scripts/check-i18n.mjs bu dosyayı en/ar eşitliği denetiminden muaf tutar.
export default {
  'admin.p15.csv': 'CSV indir',
  'admin.p15.typeDelete': 'SİL',
  'admin.p15.nav.sources': 'Kaynak durumu',
  'admin.p15.select.page': 'Sayfadaki tümünü seç',
  'admin.p15.select.row': 'Seç: {title}',
  'admin.p15.select.limit': 'En çok {max} kayıt seçilebilir.',

  // kısmi başarı raporu
  'admin.p15.report.title': 'Toplu işlem sonucu',
  'admin.p15.report.close': 'Kapat',
  'admin.p15.report.requested': '{n} kayıt istendi',
  'admin.p15.report.done': '{n} tamamlandı',
  'admin.p15.report.skipped': '{n} atlandı',
  'admin.p15.report.failed': '{n} hata',
  'admin.p15.report.problems': 'Atlanan ve hatalı kayıtlar:',
  'admin.p15.report.failedItem': 'Hata ({code})',
  'admin.p15.code.ALREADY_DONE': 'Zaten istenen durumda, değişiklik yapılmadı',
  'admin.p15.code.NOT_FOUND': 'Kayıt bulunamadı (silinmiş ya da süresi dolmuş olabilir)',
  'admin.p15.code.INTERNAL_ERROR': 'Beklenmeyen hata',

  // haber
  'admin.p15.news.noun': 'haber',
  'admin.p15.news.hide': 'Seçilenleri gizle',
  'admin.p15.news.show': 'Seçilenleri göster',
  'admin.p15.news.hide.title': '{n} haber gizlensin mi?',
  'admin.p15.news.hide.consequence':
    'Gizlenen kayıtlar herkese açık liste, detay, arama ve favorilerde görünmez. Kaynak sitedeki içerik silinmez; istediğiniz zaman tekrar gösterebilirsiniz.',
  'admin.p15.news.show.title': '{n} haber gösterilsin mi?',
  'admin.p15.news.show.consequence':
    'Seçilen haberler yeniden herkese açık liste, detay, arama ve favorilerde görünür.',

  // akademik
  'admin.p15.acd.noun.CALENDAR': 'takvim kaydı',
  'admin.p15.acd.noun.EXAM': 'sınav programı kaydı',
  'admin.p15.acd.noun.ANNOUNCEMENT': 'bölüm duyurusu',
  'admin.p15.acd.publish': 'Seçilenleri yayınla',
  'admin.p15.acd.publish.title': '{n} kayıt yayınlansın mı?',
  'admin.p15.acd.publish.consequence': 'Seçilen kayıtlar öğrencilere görünür olur. Zaten yayında olanlar atlanır.',
  'admin.p15.acd.publish.consequenceAnn':
    'Seçilen duyurular öğrencilere görünür olur. Bildirimi açık ve henüz bildirilmemiş duyurular için hedef kitleye bildirim gönderilir (bir kez). Zaten yayında olanlar atlanır.',
  'admin.p15.acd.unpublish': 'Seçilenleri yayından kaldır',
  'admin.p15.acd.unpublish.title': '{n} kayıt yayından kaldırılsın mı?',
  'admin.p15.acd.unpublish.consequence':
    'Seçilen kayıtlar öğrencilere görünmez olur ve taslağa döner; daha sonra yeniden yayınlayabilirsiniz. Gönderilmiş bildirimler geri alınmaz.',
  'admin.p15.acd.delete': 'Seçilenleri sil',
  'admin.p15.acd.delete.title': '{n} kayıt silinsin mi?',
  'admin.p15.acd.delete.consequence':
    'Seçilen kayıtlar kalıcı olarak silinir ve geri getirilemez (duyurularda okundu bilgileri de silinir). Yalnızca yayından kaldırmak yeterliyse bunu seçmeyin.',

  // menü
  'admin.p15.menu.noun': 'menü günü',
  'admin.p15.menu.select': 'Seç: {date}',
  'admin.p15.menu.selectAll': 'Aydaki tüm günleri seç',
  'admin.p15.menu.delete': 'Seçilen günleri sil',
  'admin.p15.menu.delete.title': '{n} menü günü silinsin mi?',
  'admin.p15.menu.delete.message':
    'Günün yemek listesi ve varsa fotoğrafı silinir. Kaynak site aylık senkronda silinen günü yeniden yazabilir.',
  'admin.p15.menu.delete.consequence':
    'Silinen günler uygulamada görünmez; fotoğraf dosyaları başka bir kayıt kullanmıyorsa kaldırılır. Geri alınamaz.',

  // bekleyen kayıt
  'admin.p15.pending.noun': 'bekleyen kayıt',
  'admin.p15.pending.cancel': 'Seçilenleri iptal et',
  'admin.p15.pending.cancel.title': '{n} bekleyen kayıt iptal edilsin mi?',
  'admin.p15.pending.cancel.consequence':
    'Doğrulanmamış kayıtlar silinir; hesap oluşmadığı için kullanıcı yeniden kayıt olabilir. Gönderilmiş doğrulama kodları geçersiz olur.',

  // kaynak durumu sayfası
  'admin.p15.sources.title': 'Kaynak durumu',
  'admin.p15.sources.intro':
    'Haber, duyuru, etkinlik ve yemek listesi kaynaklarının son senkron durumu. Bu sayfa yalnızca mevcut kayıtları özetler; kaynak siteye kendiliğinden istek atmaz.',
  'admin.p15.sources.rule':
    'Kaynak siteye normalde yalnızca zamanlayıcı istek atar (haber: her gece, yemek listesi: ayda bir). Elle senkron bu kuralın istisnasıdır; yalnızca kaynak güncellenmiş ve beklenemiyorsa kullanın.',
  'admin.p15.sources.limit': 'Elle senkron kaynak başına saatte en çok {n} kez çalıştırılabilir; sınır dolarsa bir süre beklemeniz gerekir.',
  'admin.p15.sources.news': 'Haber, duyuru ve etkinlik',
  'admin.p15.sources.menu': 'Yemek listesi',
  'admin.p15.sources.ok': 'Çalışıyor',
  'admin.p15.sources.maintenance': 'Bakımda',
  'admin.p15.sources.never': 'Hiç',
  'admin.p15.sources.lastSuccess': 'Son başarılı senkron',
  'admin.p15.sources.lastAttempt': 'Son deneme',
  'admin.p15.sources.message': 'Son mesaj',
  'admin.p15.sources.itemsLast7d': 'Son 7 günde çekilen',
  'admin.p15.sources.total': 'Toplam kayıt',
  'admin.p15.sources.hidden': 'Gizlenen',
  'admin.p15.sources.menuTotal': 'Kayıtlı gün',
  'admin.p15.sources.menuUpcoming': 'Bugün ve sonrası',
  'admin.p15.sources.menuImages': 'Fotoğraflı gün',
  'admin.p15.sources.run': 'Şimdi senkronize et',
  'admin.p15.sources.confirmTitle.NEWS': 'Haber kaynağı elle senkronize edilsin mi?',
  'admin.p15.sources.confirmTitle.MENU': 'Yemek listesi elle senkronize edilsin mi?',
  'admin.p15.sources.confirmMessage':
    'Kaynak siteye istek atar: scraper kuralları gereği günde yalnızca zamanlayıcı istek atar, bu elle tetikleme bir istisnadır.',
  'admin.p15.sources.confirmConsequence':
    'İşlem birkaç dakika sürebilir. Kaynak başına saatte en çok {n} kez çalışır; yeni kayıtlar eklenir, mevcut kayıtlar yeniden çekilmez.',
  'admin.p15.sources.doneNews': 'Haber senkronu tamamlandı: {summary}',
  'admin.p15.sources.doneMenu': 'Menü senkronu tamamlandı: {n} gün değişti',
  'admin.p15.sources.noNew': 'yeni kayıt yok',
};
