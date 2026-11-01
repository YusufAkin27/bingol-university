// Yönetim paneli görsel kiti (components/ui + components/charts). Panel yalnız Türkçedir: en/ar karşılığı yazılmaz,
// i18n/bundles/admin-tr-only.ts en/ar sözlüklerine aynı Türkçe metni katar; scripts/check-i18n.mjs bu dosyayı muaf tutar.
export default {
  'admin.kit.state.error': 'Bu bilgi şu an yüklenemedi.',
  'admin.kit.state.empty': 'Henüz veri yok.',
  'admin.kit.state.emptyChart': 'Bu aralıkta gösterilecek veri yok.',

  'admin.kit.delta.up': '{compare} %{value} fazla',
  'admin.kit.delta.down': '{compare} %{value} az',
  'admin.kit.delta.same': '{compare} aynı',
  'admin.kit.delta.none': 'Karşılaştırılacak eski veri yok',
  'admin.kit.delta.compareDefault': 'Öncekine göre',
  'admin.kit.delta.good': 'Bu iyi bir gelişme.',
  'admin.kit.delta.bad': 'Dikkat edilmesi gerekiyor.',

  'admin.kit.tile.spark': 'Son {count} ölçüm: ilk {first}, son {last}, en yüksek {max}.',

  'admin.kit.ring.value': '{label}: yüzde {value}',

  'admin.kit.ranked.showAll': 'Tümünü göster ({count})',
  'admin.kit.ranked.showLess': 'Daha az göster',
  'admin.kit.ranked.share': 'toplamın %{value}',

  'admin.kit.status.success': 'Sorun yok',
  'admin.kit.status.warning': 'Dikkat',
  'admin.kit.status.danger': 'Sorun var',
  'admin.kit.status.info': 'Bilgi',
  'admin.kit.status.neutral': 'Durum bilinmiyor',
  'admin.kit.status.primary': 'Öne çıkan',

  'admin.kit.legend.label': 'Renk açıklaması',

  'admin.kit.chart.showTable': 'Veriyi tablo olarak göster',
  'admin.kit.chart.hideTable': 'Tabloyu gizle',
  'admin.kit.chart.tableCaption': '{title} (tablo olarak)',
  'admin.kit.chart.loading': 'Grafik yükleniyor…',

  'admin.kit.cards.sortBy': 'Sırala',
  'admin.kit.cards.direction.asc': 'Küçükten büyüğe',
  'admin.kit.cards.direction.desc': 'Büyükten küçüğe',
  'admin.kit.cards.details': 'Diğer bilgiler ({count})',
  'admin.kit.cards.list': 'Kayıt kartları',
  'admin.kit.cards.noSort': 'Sıralama yok',

  'admin.kit.scroll.region': 'Yana kaydırılabilir alan',
  'admin.kit.scroll.hint': 'Daha fazlasını görmek için yana kaydırın',

  'admin.kit.unit.k': 'B',
  'admin.kit.unit.m': 'Mn',
  'admin.kit.unit.b': 'Mr',
  'admin.kit.unit.t': 'Tn',

  'admin.kit.time.now': 'Az önce',
  'admin.kit.time.soon': 'Birazdan',
  'admin.kit.time.minutes': '{n} dk önce',
  'admin.kit.time.hours': '{n} sa önce',
  'admin.kit.time.yesterday': 'Dün',
  'admin.kit.time.days': '{n} gün önce',
  'admin.kit.time.inMinutes': '{n} dk sonra',
  'admin.kit.time.inHours': '{n} sa sonra',
  'admin.kit.time.tomorrow': 'Yarın',
  'admin.kit.time.inDays': '{n} gün sonra',

  'admin.kit.insight.more': '%{value} fazla',
  'admin.kit.insight.less': '%{value} az',
  'admin.kit.insight.same': 'aynı',
  'admin.kit.insight.noPrevious': '{then} hiç yoktu',
  'admin.kit.insight.was': '{then} {previous} idi: ',
} as const;
