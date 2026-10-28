// Yönetim paneli etkinlik derin yönetimi (P07): başvuru, yoklama, sertifika, geri bildirim, duyuru, düzenleyen, toplu işlem.
// Yönetim paneli YALNIZ Türkçedir: bu dosyanın en/ar karşılığı yazılmaz; i18n/index.ts en/ar sözlüklerine aynı Türkçe
// metni katar ve scripts/check-i18n.mjs bu dosyayı en/ar eşitliği denetiminden muaf tutar.
export default {
  'admin.p07.csv': 'CSV indir',
  'admin.p07.unlimited': 'Sınırsız',
  'admin.p07.col.person': 'Kişi',
  'admin.p07.col.status': 'Durum',
  'admin.p07.col.date': 'Tarih',
  'admin.p07.col.actions': 'İşlem',

  'admin.p07.tabs': 'Etkinlik bölümleri',
  'admin.p07.tab.info': 'Genel',
  'admin.p07.tab.applications': 'Başvurular',
  'admin.p07.tab.attendance': 'Yoklama',
  'admin.p07.tab.certificates': 'Sertifikalar',
  'admin.p07.tab.feedback': 'Geri bildirim',
  'admin.p07.tab.announcements': 'Duyurular',
  'admin.p07.tab.organizers': 'Düzenleyenler',
  'admin.p07.tab.audit': 'Denetim',

  // başvurular
  'admin.p07.app.filter': 'Durum',
  'admin.p07.app.all': 'Tümü',
  'admin.p07.app.status.PENDING': 'Bekleyen',
  'admin.p07.app.status.WAITLISTED': 'Bekleme listesi',
  'admin.p07.app.status.ACCEPTED': 'Kabul edildi',
  'admin.p07.app.status.REJECTED': 'Reddedildi',
  'admin.p07.app.status.CANCELLED': 'Vazgeçti / kapandı',
  'admin.p07.app.capacity': 'Kapasite',
  'admin.p07.app.going': 'Katılan',
  'admin.p07.app.seatsLeft': 'Boş yer',
  'admin.p07.app.openMode':
    'Bu etkinlik herkese açık: başvuru istenmiyor, yalnız eski başvurular listelenir.',
  'admin.p07.app.notLive': 'Etkinlik yayında olmadığından başvuru kararı verilemez.',
  'admin.p07.app.full':
    'Kapasite dolu: yer açılmadan kabul edilemez (kapasite aşılamaz). Reddederek ya da kapasiteyi düzenleyerek yer açabilirsiniz.',
  'admin.p07.app.empty': 'Başvuru yok',
  'admin.p07.app.col.answers': 'Not ve yanıtlar',
  'admin.p07.app.accept': 'Kabul et',
  'admin.p07.app.accept.title': '{name} başvurusu kabul edilsin mi?',
  'admin.p07.app.accept.consequence':
    'Başvuran etkinliğe katılımcı olur ve bildirim alır. Kapasite doluysa işlem reddedilir; kapasite aşılamaz.',
  'admin.p07.app.accept.confirm': 'Kabul et',
  'admin.p07.app.accept.done': 'Başvuru kabul edildi',
  'admin.p07.app.reject': 'Reddet',
  'admin.p07.app.reject.title': '{name} başvurusu reddedilsin mi?',
  'admin.p07.app.reject.consequence': 'Başvuran bildirim alır. Reddedilen başvuru yeniden kabul edilemez.',
  'admin.p07.app.reject.consequenceAccepted':
    'Kabul edilmiş katılımcı etkinlikten çıkarılır ve bildirim alır; boşalan yere bekleme listesindeki ilk kişi otomatik alınır. Geri alınamaz.',
  'admin.p07.app.reject.confirm': 'Reddet',
  'admin.p07.app.reject.done': 'Başvuru reddedildi',

  // yoklama
  'admin.p07.att.search': 'Ada göre ara',
  'admin.p07.att.filter': 'Yoklama durumu',
  'admin.p07.att.all': 'Tümü',
  'admin.p07.att.state.present': 'Geldi',
  'admin.p07.att.state.absent': 'Gelmedi',
  'admin.p07.att.state.unmarked': 'İşaretsiz',
  'admin.p07.att.sum.going': 'Katılacak',
  'admin.p07.att.sum.present': 'Gelen',
  'admin.p07.att.sum.absent': 'Gelmeyen',
  'admin.p07.att.sum.unmarked': 'İşaretsiz',
  'admin.p07.att.sum.walkIns': 'Kapıdan gelen',
  'admin.p07.att.truncated':
    'Liste ilk 5.000 kişiyle sınırlandı; tamamı için CSV kullanılamaz, etkinliği daraltın.',
  'admin.p07.att.empty': 'Yoklama listesi boş',
  'admin.p07.att.col.marked': 'İşaretleme',
  'admin.p07.att.walkIn': 'Kapıdan (kayıtsız)',
  'admin.p07.att.cert.issued': 'Sertifikası var',
  'admin.p07.att.cert.revoked': 'Sertifikası iptal',
  'admin.p07.att.method.QR': 'QR ile',
  'admin.p07.att.method.MANUAL': 'Elle',
  'admin.p07.att.markPresent': 'Geldi yap',
  'admin.p07.att.markAbsent': 'Gelmedi yap',
  'admin.p07.att.markPresent.title': '{name} geldi olarak işaretlensin mi?',
  'admin.p07.att.markAbsent.title': '{name} gelmedi olarak işaretlensin mi?',
  'admin.p07.att.consequence':
    'Yoklama düzeltmesi sizin adınıza kaydedilir ve geri alınabilir (tersini işaretleyin). Yoklama penceresi (başlangıçtan 30 dk önce) açılmadıysa sunucu reddeder.',
  'admin.p07.att.certInvalidates':
    'Bu kişinin sertifikası geçersiz sayılır (kayıt silinmez); yeniden "geldi" yapılırsa tekrar geçerli olur.',
  'admin.p07.att.certStaysRevoked':
    'Sertifikası iptal edilmiş; yoklamayı düzeltmek iptali kaldırmaz (Sertifikalar sekmesinden geri alınır).',
  'admin.p07.att.confirm': 'Düzelt',
  'admin.p07.att.done': 'Yoklama düzeltildi',

  // sertifikalar
  'admin.p07.cert.hint':
    'Sertifika kodunun yalnız bir bölümü gösterilir. İptal edilen sertifika doğrulamada geçersiz olur ve kullanıcı yeniden alamaz.',
  'admin.p07.cert.empty': 'Bu etkinlik için düzenlenmiş sertifika yok',
  'admin.p07.cert.valid': 'Geçerli',
  'admin.p07.cert.revoked': 'İptal edildi',
  'admin.p07.cert.notAttended': 'Yoklama yok: geçersiz',
  'admin.p07.cert.code': 'Kod',
  'admin.p07.cert.reason': 'İptal sebebi',
  'admin.p07.cert.revoke': 'İptal et',
  'admin.p07.cert.revoke.title': '{name} sertifikası iptal edilsin mi?',
  'admin.p07.cert.revoke.consequence':
    'Sertifika doğrulamada geçersiz olur ve kullanıcı yeniden alamaz. İptal daha sonra "Geri al" ile kaldırılabilir. Onaylamak için İPTAL yazın.',
  'admin.p07.cert.revoke.confirm': 'Sertifikayı iptal et',
  'admin.p07.cert.revoke.done': 'Sertifika iptal edildi',
  'admin.p07.cert.restore': 'Geri al',
  'admin.p07.cert.restore.title': '{name} sertifika iptali geri alınsın mı?',
  'admin.p07.cert.restore.consequence': 'Sertifika yoklaması varsa yeniden geçerli olur.',
  'admin.p07.cert.restore.confirm': 'İptali geri al',
  'admin.p07.cert.restore.done': 'Sertifika iptali geri alındı',

  // geri bildirim
  'admin.p07.fb.anonymous': 'Geri bildirimler anonimdir: yazanın kimliği hiçbir ekranda gösterilmez.',
  'admin.p07.fb.average': 'Ortalama {avg} / 5 ({total} yanıt)',
  'admin.p07.fb.stars': '{n} yıldız',
  'admin.p07.fb.empty': 'Geri bildirim yok',
  'admin.p07.fb.rating': 'Puan: {n} / 5',
  'admin.p07.fb.noComment': 'Yorum yok',
  'admin.p07.fb.delete': 'Sil',
  'admin.p07.fb.delete.title': 'Geri bildirim silinsin mi?',
  'admin.p07.fb.delete.consequence':
    'Puan ve yorum kalıcı silinir, ortalama değişir. Yazan kişi dilerse yeniden geri bildirim gönderebilir. Geri alınamaz.',
  'admin.p07.fb.delete.confirm': 'Sil',
  'admin.p07.fb.delete.done': 'Geri bildirim silindi',

  // duyurular
  'admin.p07.ann.hint':
    'Duyuru metni saklanmaz; yalnız gönderim kaydı listelenir. Kaydı silmek alıcılara giden bildirimleri geri almaz.',
  'admin.p07.ann.empty': 'Duyuru kaydı yok',
  'admin.p07.ann.sender': 'Gönderen',
  'admin.p07.ann.recipients': '{n} alıcı',
  'admin.p07.ann.delete': 'Kaydı sil',
  'admin.p07.ann.delete.title': 'Duyuru kaydı silinsin mi?',
  'admin.p07.ann.delete.consequence':
    'Yalnız kayıt silinir; gönderilmiş bildirimler geri alınmaz. Kayıt günlük duyuru sınırına sayıldığından organizatör o gün için yeniden duyuru hakkı kazanır. Geri alınamaz.',
  'admin.p07.ann.delete.confirm': 'Kaydı sil',
  'admin.p07.ann.delete.done': 'Duyuru kaydı silindi',

  // düzenleyenler
  'admin.p07.org.empty': 'Düzenleyen bulunamadı',
  'admin.p07.org.role.OWNER': 'Sahip',
  'admin.p07.org.role.CO_ORGANIZER': 'Ortak düzenleyen',
  'admin.p07.org.protected': 'Sahip çıkarılamaz',
  'admin.p07.org.remove': 'Çıkar',
  'admin.p07.org.remove.title': '{name} düzenleyenlerden çıkarılsın mı?',
  'admin.p07.org.remove.consequence':
    'Kişi etkinliği yönetme yetkisini (yoklama, başvuru, duyuru) kaybeder. Sahip çıkarılamaz; etkinliğin son aktif düzenleyeni de çıkarılamaz. Yeniden eklemeyi etkinlik sahibi yapar.',
  'admin.p07.org.remove.confirm': 'Çıkar',
  'admin.p07.org.remove.done': 'Düzenleyen çıkarıldı',

  // toplu işlem (liste)
  'admin.p07.bulk.select': '{title} etkinliğini seç',
  'admin.p07.bulk.selectAll': 'Sayfadakilerin tümünü seç',
  'admin.p07.bulk.err.EVENT_INVALID_TRANSITION': 'Etkinliğin durumu bu işleme uygun değil',
  'admin.p07.bulk.err.EVENT_NOT_FOUND': 'Etkinlik bulunamadı',
  'admin.p07.bulk.err.VALIDATION_ERROR': 'Geçersiz istek',
  'admin.p07.bulk.err.INTERNAL_ERROR': 'Beklenmeyen hata',
  'admin.p07.bulk.noun': 'etkinlik',
  'admin.p07.bulk.limit': 'Tek seferde en fazla {max} etkinlik seçilebilir.',
  'admin.p07.bulk.hide': 'Seçilenleri gizle',
  'admin.p07.bulk.hide.title': '{n} etkinlik gizlensin mi?',
  'admin.p07.bulk.hide.consequence':
    'Yalnız yayındaki etkinlikler gizlenir (sessiz, bildirim gitmez); başkaları atlanır ve raporlanır. Her biri tek tek geri alınabilir.',
  'admin.p07.bulk.hide.confirm': 'Gizle',
  'admin.p07.bulk.cancel': 'Seçilenleri iptal et',
  'admin.p07.bulk.cancel.title': '{n} etkinlik iptal edilsin mi?',
  'admin.p07.bulk.cancel.consequence':
    'Etkinlikler kalıcı iptal edilir; katılımcılara, başvuranlara ve sahiplerine bildirim gider, sohbet odaları kapanır. Geri alınamaz. Uygun olmayanlar atlanır ve raporlanır.',
  'admin.p07.bulk.cancel.confirm': 'İptal et',
  'admin.p07.bulk.result.title': 'Toplu işlem raporu',
  'admin.p07.bulk.result.summary': '{done} / {total} etkinlik işlendi, {failed} atlandı.',
  'admin.p07.bulk.result.failed': 'Atlanan etkinlikler',
  'admin.p07.bulk.result.item': '#{id}: {reason}',
  'admin.p07.bulk.result.close': 'Kapat',
  'admin.p07.exportList': 'Listeyi CSV indir',
};
