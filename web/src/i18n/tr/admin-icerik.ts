// Yönetici: Akademik ve içerik sayfaları iyileştirmesi (takvim çizelgesi, menü kalori grafiği, kaynak ızgarası, haber dağılımı).
// Yalnız Türkçe; sayfaların kendi tembel parçasında yüklenir (pages/admin/icerik/dict.ts).
const m = {
  // ---- Akademik takvim: çizelge ----
  'admin.icerik.tl.tab': 'Çizelge',
  'admin.icerik.tl.title': 'Dönem çizelgesi',
  'admin.icerik.tl.chartLabel': 'Akademik takvim çizelgesi: olay türüne göre zaman çubukları',
  'admin.icerik.tl.range': '{from} – {to}',
  'admin.icerik.tl.prev': 'Önceki 3 ay',
  'admin.icerik.tl.next': 'Sonraki 3 ay',
  'admin.icerik.tl.goToday': 'Bugüne git',
  'admin.icerik.tl.todayMark': 'Bugün',
  'admin.icerik.tl.todayLine': 'Bugün çizgisi: {date}',
  'admin.icerik.tl.laneCount': '{n} olay',
  'admin.icerik.tl.draftTag': 'Taslak',
  'admin.icerik.tl.continuesBefore': 'önceki aylardan devam ediyor',
  'admin.icerik.tl.continuesAfter': 'sonraki aylara sürüyor',
  'admin.icerik.tl.openEvent': '{title}, {kind}, {when}{extra}. Düzenlemek için açın.',
  'admin.icerik.tl.scrollLabel': 'Yana kaydırılabilir çizelge',
  'admin.icerik.tl.emptyTitle': 'Bu aylarda takvim olayı yok',
  'admin.icerik.tl.emptyHint': 'Önceki ya da sonraki aylara bakın, ya da bu döneme yeni bir olay ekleyin.',
  'admin.icerik.tl.upcoming.title': 'Yaklaşan olaylar',
  'admin.icerik.tl.upcoming.ongoing': 'Şu an sürüyor',
  'admin.icerik.tl.upcoming.nextLabel': 'Sırada',
  'admin.icerik.tl.upcoming.empty': 'Yaklaşan olay yok.',
  'admin.icerik.tl.when.today': 'bugün',
  'admin.icerik.tl.when.tomorrow': 'yarın',
  'admin.icerik.tl.when.inDays': '{n} gün sonra',
  'admin.icerik.tl.when.endsToday': 'bugün bitiyor',
  'admin.icerik.tl.when.endsIn': 'bitmesine {n} gün',
  'admin.icerik.tl.insight.none':
    'Önümüzdeki günlerde planlanmış bir olay yok. Dönemi planlamak için takvime yeni bir olay ekleyin.',
  'admin.icerik.tl.insight.next':
    'Sıradaki olay "{title}" ({when}). Önümüzdeki {days} günde toplam {n} olay var.',
  'admin.icerik.tl.insight.ongoing':
    'Şu an {n} olay sürüyor: "{title}" ({when}). Önümüzdeki {days} günde toplam {total} olay var.',
  'admin.icerik.tl.insight.draft':
    '{n} yaklaşan olay taslakta: yayınlanana kadar mobil uygulamada görünmez.',

  // ---- Yemek menüsü: kalori grafiği ----
  'admin.icerik.menu.kcal.title': 'Günlük toplam kalori',
  'admin.icerik.menu.kcal.chartLabel': 'Ayın günlük toplam kalori çubukları',
  'admin.icerik.menu.kcal.insight.none':
    'Bu ay henüz hiçbir yemeğin kalorisi girilmemiş. Aşağıdan günleri açın ya da toplu yapıştırın.',
  'admin.icerik.menu.kcal.insight.ok':
    'Günlük ortalama {avg} kcal; en yüksek gün {date} ({max} kcal). Tüm yemeklerin kalorisi girilmiş.',
  'admin.icerik.menu.kcal.insight.missing':
    '{dishes} yemeğin kalorisi eksik ({days} güne dağılmış). Çizgili çubuklar yalnız bilinen kısmı gösterir; günlük ortalama {avg} kcal.',
  'admin.icerik.menu.kcal.insight.missingNoAvg':
    '{dishes} yemeğin kalorisi eksik ({days} güne dağılmış); henüz tamamı girilmiş bir gün yok. Çizgili çubuklar yalnız bilinen kısmı gösterir.',
  'admin.icerik.menu.kcal.legend.full': 'Tamamı girilmiş',
  'admin.icerik.menu.kcal.legend.partial': 'Eksik var (bilinen kısım)',
  'admin.icerik.menu.kcal.legend.none': 'Hiç girilmemiş',
  'admin.icerik.menu.kcal.bar.full': '{date}: {kcal} kcal',
  'admin.icerik.menu.kcal.bar.partial': '{date}: en az {kcal} kcal, {missing} yemeğin kalorisi eksik',
  'admin.icerik.menu.kcal.bar.none': '{date}: kalori girilmemiş',
  'admin.icerik.menu.kcal.open': 'Günü aç ve kaloriyi düzenle',
  'admin.icerik.menu.kcal.coverage': 'yemeğin kalorisi girilmiş',
  'admin.icerik.menu.kcal.coverageValue': '{known} / {all}',
  'admin.icerik.menu.kcal.goFirst': 'İlk eksik güne git',
  'admin.icerik.menu.kcal.axisMax': 'En yüksek: {kcal} kcal',

  // ---- Kaynak durumu: ızgara ----
  'admin.icerik.src.grid.title': 'Tüm kaynaklar bir bakışta',
  'admin.icerik.src.grid.label': 'Kaynak sağlığı ızgarası',
  'admin.icerik.src.grid.coreNews': 'Haber · duyuru · etkinlik',
  'admin.icerik.src.grid.coreMenu': 'Yemek listesi',
  'admin.icerik.src.grid.core': 'Ana kaynaklar',
  'admin.icerik.src.grid.units': 'Birim siteleri ({n})',
  'admin.icerik.src.grid.unitsErrorSubject': 'Birim siteleri',
  'admin.icerik.src.grid.unitsEmpty': 'Tanımlı birim kaynağı yok.',
  'admin.icerik.src.grid.ringLabel': 'kaynak sorunsuz çalışıyor',
  'admin.icerik.src.grid.insight.allGood': 'Tüm {n} kaynak sorunsuz çalışıyor. Yapmanız gereken bir şey yok.',
  'admin.icerik.src.grid.insight.some':
    '{n} kaynaktan {ok} tanesi sorunsuz; {bad} kaynak ilginizi bekliyor (bakımda, hiç çekilmemiş ya da 2 günden eski).',
  'admin.icerik.src.grid.last': 'Son çekim: {when}',
  'admin.icerik.src.grid.lastNever': 'Henüz hiç çekilmedi',
  'admin.icerik.src.grid.announcements': '{n} duyuru',
  'admin.icerik.src.grid.openUnit': 'Birim haberleri sayfasında yönet',
  'admin.icerik.src.state.ok': 'Çalışıyor',
  'admin.icerik.src.state.stale': 'Güncel değil',
  'admin.icerik.src.state.maintenance': 'Bakımda',
  'admin.icerik.src.state.never': 'Hiç çekilmedi',
  'admin.icerik.src.state.disabled': 'Kapalı',
  'admin.icerik.src.legend.title': 'Durumlar',

  // ---- Haber yönetimi: dağılım ----
  'admin.icerik.news.dist.title': 'Kayıt dağılımı',
  'admin.icerik.news.dist.label': 'Haber, duyuru ve etkinlik dağılımı',
  'admin.icerik.news.dist.insight':
    'Toplam {total} kayıt var ({parts}). Son 7 günde {week} yeni kayıt geldi; {hidden} kayıt gizli.',
  'admin.icerik.news.dist.insightNone': 'Henüz kayıt yok; ilk güncellemeden sonra dağılım burada görünür.',
  'admin.icerik.news.sum.total': 'Toplam kayıt',
  'admin.icerik.news.sum.totalCap': 'Haber, duyuru ve etkinlik birlikte',
  'admin.icerik.news.sum.week': 'Son 7 günde gelen',
  'admin.icerik.news.sum.weekCap': 'Kaynak siteden yeni alınan',
  'admin.icerik.news.sum.hidden': 'Gizlenen kayıt',
  'admin.icerik.news.sum.hiddenCap': 'Uygulamada görünmez (tüm sayfalar)',
  'admin.icerik.news.filtered': 'Süzgece uyan {n} kayıt listeleniyor.',

  // ---- Birim haberleri: dağılım ----
  'admin.icerik.unit.dist.title': 'Hangi birimden kaç duyuru?',
  'admin.icerik.unit.dist.label': 'Birimlere göre duyuru sayısı',
  'admin.icerik.unit.dist.insight': 'Toplam {total} duyuru var; en çok duyuru "{top}" biriminden geliyor ({n}).',
  'admin.icerik.unit.dist.insightEmpty': 'Henüz birim duyurusu çekilmedi; ilk gece çekiminden sonra dağılım görünür.',
  'admin.icerik.unit.dist.hint': '{n} duyuru',
} as const;
export default m;
