// Topluluk, akademik ve içerik sayfaları görsel yenileme metinleri (COMM). Panel yalnız Türkçedir (bkz. admin-kit.ts).
export default {
  // Haberler
  'admin.v2.news.sum.total': 'Listedeki haber',
  'admin.v2.news.sum.totalCap': 'Süzgece uyan toplam kayıt',
  'admin.v2.news.sum.hidden': 'Bu sayfada gizli',
  'admin.v2.news.sum.hiddenCap': 'Görünen sayfadaki gizlenmiş kayıt',
  'admin.v2.news.insight.noHidden': '{total} kayıt var, bu sayfadakilerin hepsi uygulamada görünüyor.',
  'admin.v2.news.insight.hidden': '{total} kayıt var; bu sayfadaki {hidden} tanesi gizli, uygulamada görünmüyor.',
  'admin.v2.news.insight.empty': 'Süzgece uyan haber yok.',
  'admin.v2.news.syncAge.never': 'Henüz hiç güncellenmedi.',
  'admin.v2.news.syncAge.ago': 'Son başarılı güncelleme {ago}.',
  'admin.v2.news.syncOk': 'Kaynak site çalışıyor, liste güncel.',
  'admin.v2.news.syncMaintenance':
    'Kaynak siteden son zamanlarda veri alınamadı; uygulamada eski liste gösteriliyor. Sorun kaynak sitedeyse kendiliğinden düzelir.',
  'admin.v2.news.hideLabel': 'Gizle',
  'admin.v2.news.showLabel': 'Göster',
  'admin.v2.news.filter.typeLabel': 'Tür',
  'admin.v2.news.filter.visLabel': 'Görünürlük',

  // Ortak seçici
  'admin.v2.picker.choose': 'Seç',
  'admin.v2.picker.change': 'Değiştir',

  // Etkinlik başvuruları
  'admin.v2.apps.pickLabel': 'Etkinliği seçin',
  'admin.v2.apps.pickPlaceholder': 'Etkinlik adını yazın…',
  'admin.v2.apps.pickHint': 'Etkinliğin adından en az 2 harf yazın; uyanlar burada listelenir.',
  'admin.v2.apps.pickNone': 'Bu adla etkinlik bulunamadı. Yazımı değiştirip tekrar deneyin.',
  'admin.v2.apps.byId': 'Etkinlik numarasını biliyorum',
  'admin.v2.apps.chipMeta': 'Doluluk ve başvuru durumları',
  'admin.v2.apps.eventNo': 'Etkinlik no {id}',
  'admin.v2.apps.openEvent': 'Etkinliği aç (başvuruları ve yoklamayı gör)',
  'admin.v2.apps.sentence.limited':
    '{cap} kişilik etkinliğin {going} yeri dolu, {left} yer boş; {pending} başvuru karar bekliyor.',
  'admin.v2.apps.sentence.full': '{cap} kişilik etkinlik tamamen dolu; {pending} başvuru karar bekliyor.',
  'admin.v2.apps.sentence.unlimited': 'Kontenjan sınırı yok; {going} kişi kayıtlı, {pending} başvuru karar bekliyor.',
  'admin.v2.apps.ring': '{going} / {cap} kişi dolu',
  'admin.v2.apps.funnel': 'Başvuruların durumlara göre dağılımı',
  'admin.v2.apps.counts': 'Başvuru durumları',
  'admin.v2.apps.cap.going': 'Etkinlikte şu an yeri olan kişi (kontenjandan düşer)',
  'admin.v2.apps.cap.pending': 'Henüz karar verilmemiş başvuru',
  'admin.v2.apps.cap.accepted': 'Başvurusu onaylanan kişi. Serbest katılımda başvuru aşaması olmadığından 0 kalabilir',
  'admin.v2.apps.cap.waitlisted': 'Yer açılırsa sıradaki kişiler',
  'admin.v2.apps.cap.rejected': 'Başvurusu kabul edilmeyenler',
  'admin.v2.apps.cap.cancelled': 'Başvurusunu geri çeken ya da iptal olanlar',

  // Kulüp denetimi
  'admin.v2.audit.pickLabel': 'Kulübü seçin',
  'admin.v2.audit.pickPlaceholder': 'Kulüp adını yazın…',
  'admin.v2.audit.pickHint': 'Kulübün adından en az 2 harf yazın; uyanlar burada listelenir.',
  'admin.v2.audit.pickNone': 'Bu adla kulüp bulunamadı. Yazımı değiştirip tekrar deneyin.',
  'admin.v2.audit.pickMeta': '{n} üye · sahibi: {owner}',
  'admin.v2.audit.byId': 'Kulüp numarasını biliyorum',
  'admin.v2.audit.clubNo': 'Kulüp no {id}',
  'admin.v2.audit.chipMeta': 'Bu kulüpte kim ne yaptı: yetki, üye, devir ve davet kayıtları',
  'admin.v2.audit.insight': 'Yüklenen {n} kayıt var; en yenisi {last} tarihinde.',
  'admin.v2.audit.group.member': 'Üyelik işlemleri',
  'admin.v2.audit.group.permission': 'Yetki değişiklikleri',
  'admin.v2.audit.group.transfer': 'Sahiplik devirleri',
  'admin.v2.audit.group.invite': 'Davetler',
  'admin.v2.audit.filter': 'Kayıt türü',
  'admin.v2.audit.filterAll': 'Hepsi',
  'admin.v2.audit.filterNone': 'Bu türde kayıt yok. Başka bir tür seçin ya da “Hepsi”ni seçin.',
  'admin.v2.audit.today': 'Bugün',
  'admin.v2.audit.yesterday': 'Dün',
  'admin.v2.audit.detail': 'Teknik ayrıntı',

  // Etkinlikler
  'admin.v2.ev.sum.shown': 'Listedeki etkinlik',
  'admin.v2.ev.sum.shownCap': 'Şu ana kadar yüklenen',
  'admin.v2.ev.sum.pending': 'Karar bekleyen başvuru',
  'admin.v2.ev.sum.pendingCap': 'Listedeki etkinliklere gelen',
  'admin.v2.ev.sum.almost': 'Dolmak üzere',
  'admin.v2.ev.sum.almostCap': '%85 ve üstü dolu etkinlik',
  'admin.v2.ev.insight': 'Listede {n} etkinlik var; {pending} başvuru karar bekliyor, {full} etkinlik dolmak üzere.',
  'admin.v2.ev.fill': '{going} / {cap} kişi (%{pct} dolu)',
  'admin.v2.ev.fillOpen': '{going} kişi katılıyor (kontenjan sınırsız)',
  'admin.v2.ev.standaloneOnly': 'Yalnız kulüpsüz etkinlikler',
  'admin.v2.ev.range.week': 'Bu hafta',
  'admin.v2.ev.range.month': 'Bu ay',
  'admin.v2.ev.range.clear': 'Tarihi temizle',
  'admin.v2.ev.ruleTitle': 'Etkinlikleri kimler açabilir?',
  'admin.v2.ev.countsNote':
    'Kayıtlı katılımcı: etkinlikte şu an yeri olanlar. Kabul edilen: başvuru-onay akışında onay alan başvurular. Yoklamada gelen: QR ya da elle yoklaması alınanlar.',
  'admin.v2.ev.requestsBar': 'Katılım isteklerinin durumlara göre dağılımı',
  'admin.v2.ev.fillAria': 'Doluluk',
  'admin.v2.ev.dateHint': 'gün.ay.yıl',

  // Ortak
  'admin.v2.filters.title': 'Süzgeçler',

  // Akademik takvim
  'admin.v2.cal.viewCalendar': 'Takvim',
  'admin.v2.cal.count': '{n} kayıt',
  'admin.v2.cal.upNext': 'Yaklaşanlar:',
  'admin.v2.cal.legend': 'Renk anlamları',
  'admin.v2.cal.monthEmpty': 'Bu ayda takvim olayı yok. Başka bir aya geçin ya da “Olay ekle” düğmesini kullanın.',

  // Bölüm duyuruları
  'admin.v2.an.readSentence': 'Hedef kitlenin %{pct} kadarı okudu',

  // Sınavlar
  'admin.v2.ex.insight': 'Listede {n} sınav var; {week} tanesi bu hafta.',
  'admin.v2.ex.insightConflict':
    'Listede {n} sınav var; {week} tanesi bu hafta. {conflicts} sınav aynı sınıf ve bölümde başka bir sınavla çakışıyor, saatlerini kontrol edin.',
  'admin.v2.ex.bucket.week': 'Bu hafta',
  'admin.v2.ex.bucket.nextWeek': 'Gelecek hafta',
  'admin.v2.ex.bucket.later': 'Daha sonra',
  'admin.v2.ex.bucket.past': 'Geçmiş sınavlar',
  'admin.v2.ex.conflict': 'Saat çakışması',
  'admin.v2.ex.conflictHint': 'Aynı sınıf ve bölümde aynı saatte başka bir sınav var. Öğrenciler ikisine birden giremez.',
};
