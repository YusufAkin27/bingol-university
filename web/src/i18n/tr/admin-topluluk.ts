// Topluluk ve etkinlik sayfaları (PANEL-topluluk) ek metinleri. Panel yalnız Türkçedir; pages/admin/community/tp.ts
// bu sözlüğü sayfaların kendi tembel parçasında kayıt defterine ekler (ana admin.tr parçası şişmesin).
export default {
  // Kulüp listesi: gerçek durum dağılımı
  'admin.tp.club.insight':
    'Süzgece uyan {total} kulüpten {active} tanesi yayında, {pending} tanesi onay bekliyor.',
  'admin.tp.club.insightNone': 'Süzgece uyan kulüp yok.',
  'admin.tp.club.distTitle': 'Kulüplerin durumu',
  'admin.tp.club.distAria': 'Kulüplerin durum dağılımı (tüm sayfalar)',
  'admin.tp.club.distError': 'Durum dağılımı yüklenemedi; liste yine de çalışıyor.',
  'admin.tp.club.goQueue': 'Onay kuyruğunu aç ({n})',
  'admin.tp.club.sumTotal': 'Toplam kulüp',
  'admin.tp.club.sumTotalCap': 'Süzgece uyan tüm sayfalar',
  'admin.tp.club.sumActive': 'Yayında',
  'admin.tp.club.sumActiveCap': 'Uygulamada görünen kulüp',
  'admin.tp.club.sumPending': 'Onay bekliyor',
  'admin.tp.club.sumPendingCap': 'Karar vermenizi bekleyen kulüp',
  'admin.tp.club.topMembers': 'Bu sayfada en kalabalık kulüpler',
  'admin.tp.club.topMembersAria': 'Üye sayısına göre kulüpler',
  'admin.tp.club.membersHint': '{n} üye',

  // Onay kuyruğu (CommunitiesAdminPage)
  'admin.tp.queue.insight': '{n} kulüp onay bekliyor; en eski başvuru {days} gündür bekliyor.',
  'admin.tp.queue.insightToday': '{n} kulüp onay bekliyor; en eski başvuru bugün geldi.',
  'admin.tp.queue.insightMore': 'Listede en az {n} kulüp onay bekliyor; en eski başvuru {days} gündür bekliyor.',
  'admin.tp.queue.clear': 'Onay bekleyen kulüp kalmadı.',
  'admin.tp.queue.waiting': '{days} gündür bekliyor',
  'admin.tp.queue.waitingToday': 'Bugün geldi',
  'admin.tp.queue.stale': 'Yavaşladı: {days} gündür bekliyor',
  'admin.tp.queue.staleHint': '3 günden uzun bekleyen başvurular önce kararlaştırılmalı.',

  // Etkinlik listesi
  'admin.tp.ev.occTitle': 'Kontenjanı dolmak üzere olan etkinlikler',
  'admin.tp.ev.occAria': 'Etkinlik doluluk sıralaması',
  'admin.tp.ev.occHint': '{going} / {cap} kişi',
  'admin.tp.ev.occHintOver': '{going} / {cap} kişi, {over} kişi fazla',
  'admin.tp.ev.occInsightNone': 'Bu listede kontenjanı dolmak üzere olan etkinlik yok.',
  'admin.tp.ev.occInsight': '{n} etkinlikte kontenjanın en az %85\'i dolmuş; en dolusu "{title}" (%{pct}).',
  'admin.tp.ev.occAll': 'Tüm kontenjanlı etkinlikleri göster',
  'admin.tp.ev.moreLoaded': 'Gösterilen sayılar yüklenen {n} etkinliği kapsar; daha fazlası için aşağıdan yükleyin.',

  // Başvuru ve yoklama özetleri (etkinlik çekmecesi)
  'admin.tp.apps.insightOpen': '{going} kişi katılıyor; kontenjan sınırsız. {pending} başvuru karar bekliyor.',
  'admin.tp.apps.insightFull': 'Kontenjan dolu ({cap} kişi). {pending} başvuru karar bekliyor, {wait} kişi yedek listede.',
  'admin.tp.apps.insight': '{cap} kişilik kontenjanın {going} kişisi doldu, {left} boş yer var. {pending} başvuru karar bekliyor.',
  'admin.tp.apps.ring': '{going} / {cap} kişi katılıyor',
  'admin.tp.apps.ringUnlimited': 'kişi katılıyor',
  'admin.tp.apps.stackAria': 'Başvuruların durum dağılımı',
  'admin.tp.apps.empty': 'Bu etkinliğe henüz başvuru yok.',
  'admin.tp.att.insight': 'Katılacak {going} kişiden {present} kişi geldi (%{pct}); {unmarked} kişi henüz işaretlenmedi.',
  'admin.tp.att.insightNone': 'Yoklama alınmaya başlanmadı; {going} kişi katılacak.',
  'admin.tp.att.insightWalk': ' Ayrıca {walk} kişi kapıdan geldi.',
  'admin.tp.att.ring': 'katılacakların gelme oranı',
  'admin.tp.att.stackAria': 'Yoklama dağılımı',
  'admin.tp.att.ringEmpty': 'yoklama başlamadı',

  // Etkinlik başvuru özeti sayfası
  'admin.tp.apps.page.seatsLeft': 'Boş yer',
  'admin.tp.apps.page.seatsLeftCap': 'Kontenjandan kalan',
  'admin.tp.apps.page.seatsUnlimited': 'Sınırsız',
  'admin.tp.apps.page.counts': 'Başvuru sayıları (ayrıntı)',

  // Kulüp denetim kaydı
  'admin.tp.audit.byGroupTitle': 'Hangi işlemler yapılmış?',
  'admin.tp.audit.byGroupAria': 'Denetim kayıtlarının tür dağılımı',
  'admin.tp.audit.actorsTitle': 'En çok işlem yapanlar',
  'admin.tp.audit.actorsAria': 'İşlem sayısına göre yöneticiler',
  'admin.tp.audit.other': 'Diğer',
  'admin.tp.audit.opsCount': '{n} işlem',
  'admin.tp.audit.insight':
    'Yüklenen {n} kaydın en çok yapılan işlemi "{top}" ({count} kez). Son işlem {last}.',
  'admin.tp.audit.partial': 'Yalnız yüklenen son {n} kayıt sayıldı; daha eski kayıtlar için aşağıdan devam edin.',

  // Kulüp kategorileri
  'admin.tp.cat.insight':
    '{active} kategori aktif, {inactive} kategori pasif. {unused} kategoriyi hiçbir kulüp kullanmıyor.',
  'admin.tp.cat.top': 'En çok kullanılan: {name} ({n} kulüp).',
  'admin.tp.cat.dist': 'Kategorilere göre kulüp sayısı',
  'admin.tp.cat.distAria': 'Kategoriye göre kulüp dağılımı',
  'admin.tp.cat.usageHint': '{n} kulüp',
};
