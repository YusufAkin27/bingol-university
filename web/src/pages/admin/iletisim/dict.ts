// Yönetim paneli İLETİŞİM grubu (destek + bildirimler) görsel iyileştirme metinleri. Panel YALNIZ Türkçedir.
// Sayfaların kendi tembel parçasında yüklenir (il.ts); anahtar ön eki: admin.il.*
export default {
  // ---- ortak ----
  'admin.il.err.load': 'Bu bölüm yüklenemedi. Biraz sonra yeniden deneyin.',
  'admin.il.unit.minutes': 'dk',
  'admin.il.unit.hours': 'sa',
  'admin.il.unit.days': 'gün',

  // ---- destek talepleri ----
  'admin.il.tk.summary': 'Destek talepleri özeti',
  'admin.il.tk.tile.waiting': 'Yanıt bekleyen talep',
  'admin.il.tk.tile.waitingUnit': 'talep',
  'admin.il.tk.tile.waitingHint': 'Sizin cevabınızı bekleyenler.',
  'admin.il.tk.tile.first': 'Ortalama ilk yanıt süresi',
  'admin.il.tk.first.none': 'Son 90 günde yanıtlanan talep yok.',
  'admin.il.tk.first.good': 'İyi: bir günün altında (son 90 gün).',
  'admin.il.tk.first.warn': 'Biraz uzun: hedef bir gün (son 90 gün).',
  'admin.il.tk.first.bad': 'Çok uzun: üç günü aşıyor (son 90 gün).',
  'admin.il.tk.ring': 'talep yanıt aldı ya da kapandı',
  'admin.il.tk.sentence.none': 'Yanıt bekleyen talep yok, hepsiyle ilgilenilmiş.',
  'admin.il.tk.sentence.waiting': '{n} talep yanıtınızı bekliyor.',
  'admin.il.tk.sentence.oldest': 'En eski talebin son hareketi: {when}.',
  'admin.il.tk.sentence.stale': '3 günden uzun bekleyen {n} talep var, önce onlara bakın.',
  'admin.il.tk.dist.title': 'Taleplerin durumu',
  'admin.il.tk.dist.aria': 'Tüm talepler ({n}) durumlarına göre',
  'admin.il.tk.dist.note':
    'Bir duruma dokunursanız aşağıdaki liste o talepleri gösterir; yeniden dokunursanız süzgeç kalkar.',
  'admin.il.tk.seg.OPEN': 'Yanıt bekliyor',
  'admin.il.tk.seg.OPENHint': 'Sıra sizde',
  'admin.il.tk.seg.ANSWERED': 'Yanıtlandı',
  'admin.il.tk.seg.ANSWEREDHint': 'Kullanıcının cevabı bekleniyor',
  'admin.il.tk.seg.CLOSED': 'Kapandı',
  'admin.il.tk.seg.CLOSEDHint': 'İş tamamlandı',
  'admin.il.tk.age.title': 'Bekleyen talepler ne kadardır bekliyor?',
  'admin.il.tk.age.lt4h': '4 saatten az',
  'admin.il.tk.age.lt24h': '4-24 saat',
  'admin.il.tk.age.lt3d': '1-3 gün',
  'admin.il.tk.age.gt3d': '3 günden fazla',
  'admin.il.tk.age.series': 'Bekleyen talep',
  'admin.il.tk.age.empty': 'Bekleyen talep yok, gösterilecek bir şey kalmadı.',
  'admin.il.tk.age.more': 'Yalnızca en yeni {n} bekleyen talep sayıldı; daha fazlası olabilir.',
  'admin.il.tk.age.col.range': 'Bekleme süresi',
  'admin.il.tk.age.col.count': 'Talep sayısı',
  'admin.il.tk.ageInsight.none': 'Bekleyen talep yok.',
  'admin.il.tk.ageInsight.stale': '{total} bekleyen talebin {n} tanesi 3 günden uzun süredir cevap bekliyor.',
  'admin.il.tk.ageInsight.fresh': '{total} bekleyen talebin hiçbiri 3 günü aşmadı.',
  'admin.il.tk.col.wait': 'Son hareket',

  // ---- geri bildirim ----
  'admin.il.fb.summary': 'Geri bildirim özeti',
  'admin.il.fb.tile.new': 'İncelenmemiş geri bildirim',
  'admin.il.fb.tile.newUnit': 'kayıt',
  'admin.il.fb.tile.newHint': 'Henüz kimsenin bakmadığı yeni kayıtlar.',
  'admin.il.fb.tile.planned': 'Yapılması planlanan',
  'admin.il.fb.tile.plannedUnit': 'öneri',
  'admin.il.fb.tile.plannedHint': 'Tamamlanan öneri sayısı: {done}',
  'admin.il.fb.ring': 'geri bildirim ele alındı',
  'admin.il.fb.sentence.new': '{total} geri bildirimin {n} tanesi hâlâ yeni, henüz kimse bakmadı.',
  'admin.il.fb.sentence.none': 'Tüm geri bildirimler ele alınmış ({total} kayıt).',
  'admin.il.fb.dist.title': 'Durumlara göre dağılım',
  'admin.il.fb.dist.aria': 'Geri bildirimlerin durumu',
  'admin.il.fb.cat.title': 'Ne hakkında yazıyorlar?',
  'admin.il.fb.cat.empty': 'Henüz geri bildirim yok.',
  'admin.il.fb.cat.count': '{n} kayıt',

  // ---- bildirim kampanyaları ----
  'admin.il.cp.summary': 'Bildirim kampanyaları özeti',
  'admin.il.cp.tile.reached': 'Ulaşılan kişi',
  'admin.il.cp.tile.reachedUnit': 'kişi',
  'admin.il.cp.tile.reachedHint': 'Son {n} gönderilen kampanyada.',
  'admin.il.cp.tile.queued': 'Sırada olan kampanya',
  'admin.il.cp.tile.queuedUnit': 'kampanya',
  'admin.il.cp.tile.queuedHint': 'Zamanlanmış ya da şu an gönderilen.',
  'admin.il.cp.ring': 'gönderilen kampanyalarda hedef kitleye ulaşıldı',
  'admin.il.cp.sentence.failed':
    '{n} kampanya hata verdi; listeden "Başarısız" durumunu seçip nedenine bakın.',
  'admin.il.cp.sentence.queued': '{n} kampanya sırada: zamanlanmış ya da şu an gönderiliyor.',
  'admin.il.cp.sentence.calm': 'Sorun yok: gönderilen {n} kampanyada hata görünmüyor.',
  'admin.il.cp.dist.title': 'Kampanyaların durumu',
  'admin.il.cp.dist.aria': 'Son {n} kampanya durumlarına göre',
  'admin.il.cp.dist.note': 'Son {n} kampanya sayıldı. Bir duruma dokunursanız aşağıdaki liste süzülür.',
  'admin.il.cp.chart.title': 'Hedef kitle ve ulaşılan kişi',
  'admin.il.cp.chart.insight': '{audience} kişilik kitlenin {reached} kişisine ulaşıldı: yüzde {pct}.',
  'admin.il.cp.chart.empty': 'Kitle büyüklüğü bilinen, gönderilmiş kampanya yok.',
  'admin.il.cp.chart.note': 'Aradaki fark, bildirim tercihini kapatan kişilerdir.',
  'admin.il.cp.chart.audience': 'Hedef kitle',
  'admin.il.cp.chart.reached': 'Ulaşılan',
  'admin.il.cp.chart.col.name': 'Kampanya',

  // ---- kampanya oluşturucu: kitle oranı ----
  'admin.il.ca.share': 'Tüm kullanıcıların yüzde {pct} kadarı',
  'admin.il.ca.shareNote': 'Bu kitle {n} kişi; doğrulanmış {total} kullanıcının içinde.',

  // ---- e-posta kampanyaları ----
  'admin.il.mc.summary': 'E-posta kampanyaları özeti',
  'admin.il.mc.dist.title': 'Kampanyaların durumu',
  'admin.il.mc.dist.aria': 'Son {n} e-posta kampanyası durumlarına göre',
  'admin.il.mc.ring': 'alıcı gönderim sırasına alındı',
  'admin.il.mc.ringNote': 'Sıraya almak, gönderime hazır demektir. Açılma ve tıklama izlenmez.',
  'admin.il.mc.sentence.ok':
    'Son {n} kampanyada hedeflenen {target} alıcının {queued} tanesi sıraya alındı, hata yok.',
  'admin.il.mc.sentence.problem':
    'Dikkat: {campaigns} kampanya başarısız, {failed} alıcının e-postası sıraya alınamadı.',
  'admin.il.mc.detail.sentence':
    '{target} alıcının {queued} tanesi sıraya alındı; {skipped} atlandı, {failed} başarısız.',

  // ---- kuyruk sağlığı (mail + bildirim) ----
  'admin.il.qh.loading': 'Kuyruk durumu yükleniyor',
  'admin.il.qh.pushTitle': 'Bildirim kuyruğunun sağlığı',
  'admin.il.qh.status.good': 'Sorunsuz',
  'admin.il.qh.status.warn': 'Dikkat',
  'admin.il.qh.status.bad': 'Müdahale gerekli',
  'admin.il.qh.bad': '{n} kayıt gönderilemedi ve tekrar denemelerden vazgeçildi; kendiliğinden gitmeyecek.',
  'admin.il.qh.warn': '{n} kayıt geçici hata aldı, sistem otomatik yeniden deniyor.',
  'admin.il.qh.good': 'Kuyruk temiz, takılan kayıt yok.',
  'admin.il.qh.oldest': 'En eski bekleyen kayıt {when} sıraya girdi.',
  'admin.il.qh.sent24': 'Son 24 saatte {n} gönderildi.',
  'admin.il.qh.hint': 'Bir duruma dokunursanız aşağıdaki liste o kayıtlara süzülür.',

  // ---- e-posta engel listesi ----
  'admin.il.sp.loading': 'Engel listesi özeti yükleniyor',
  'admin.il.sp.summary': 'E-posta engel listesi özeti',
  'admin.il.sp.dist.aria': 'Engelli {n} adres nedenlerine göre',
  'admin.il.sp.hint.UNSUBSCRIBED': 'Kendisi abonelikten çıktı',
  'admin.il.sp.hint.BOUNCED': 'Adres geçersiz ya da dolu',
  'admin.il.sp.hint.COMPLAINT': 'Spam olarak işaretledi',
  'admin.il.sp.hint.MANUAL': 'Yönetici ekledi',
  'admin.il.sp.sentence.ok':
    'Toplam {total} adres engelli; {optOut} tanesi kendi isteğiyle çıktı. Bu adreslere duyuru e-postası gitmez.',
  'admin.il.sp.sentence.complaint':
    '{complaint} kişi e-postayı spam olarak işaretledi. Bu engelleri kaldırmayın; alan adının itibarı zarar görür. Toplam {total} adres engelli.',

  // ---- e-posta şablonları ----
  'admin.il.tp.loading': 'Şablon özeti yükleniyor',
  'admin.il.tp.summary': 'E-posta şablonları özeti',
  'admin.il.tp.dist.aria': 'Son {n} şablon durumlarına göre',
  'admin.il.tp.sentence.ok': 'Yayındaki {pub} şablonun hepsi üç dilde hazır.',
  'admin.il.tp.sentence.missing':
    'Yayındaki {pub} şablonun {n} tanesinde eksik dil var; o dili seçen alıcılara yedek dil gider.',

  // ---- bildirim altyapısı: istatistik ve cihazlar ----
  'admin.il.ps.readHint': 'Kullanıcının açıp okuduğu bildirimler.',
  'admin.il.ps.ring': 'bildirim okundu',
  'admin.il.ps.inbox': 'Bildirim kutularında toplam {total} bildirim var, {unread} tanesi okunmamış.',
  'admin.il.pd.ring': 'cihaz son 7 günde açıldı',
  'admin.il.pd.totalHint': '{users} kullanıcıya ait.',
  'admin.il.pd.sentence':
    '{total} kayıtlı cihazın {active} tanesi son 7 günde uygulamayı açtı; {stale} cihaz 30 günden uzun süredir görünmedi.',
} as Record<string, string>;
