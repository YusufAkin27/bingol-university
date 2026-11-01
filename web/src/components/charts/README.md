# Yönetim paneli görsel kiti

Amaç: panelde **önce özet, sonra ayrıntı**; her sayı ve grafik bir **çocuğun bile anlayacağı düz cümleyle** gelsin;
telefonda (360-430 px) taşma olmasın.

Bileşenler iki yerde durur (recharts yalnız `charts`'ta, böylece yalnız sayı gösteren sayfa grafik paketini indirmez):

| Yer | İçe aktarma | Bileşenler |
|---|---|---|
| `components/ui` | `import { StatTile, ... } from '../../components/ui'` | `StatTile`, `DeltaBadge`, `Sparkline` (eski, `color/width/height` eklendi), `ProgressRing`, `RankedBars`, `ChartLegend`, `StatusDot`, `Insight` + `compareSentence`, `ResponsiveTable` / `DataCards`, `ScrollShadow`, `ActionBar`, `useIsNarrow`, `useKitFormat` (`formatCompact`, `formatPercent`, `percentChange`, `relativeTime`) |
| `components/charts` | `import { ChartPanel, LineAreaChart } from '../../components/charts'` | `ChartPanel` (başlık + yorum + grafik + renk açıklaması + tablo alternatifi) ve mevcut `LineAreaChart`, `BarChart`, `DonutChart`, `FunnelChart`, `CohortTable` |

Hepsi yalnız tema değişkenlerini kullanır (açık/koyu), mantıksal CSS özellikleri (RTL), `prefers-reduced-motion`
altında animasyonsuzdur. Metinler `admin.kit.*` anahtarlarındadır (`i18n/tr/admin-kit.ts`, yalnız Türkçe).

## Hızlı örnekler

### Büyük sayı kutuları (özet satırı)

```tsx
import { StatTile, percentChange } from '../../components/ui';

<div className={styles.tiles}> {/* grid: repeat(auto-fit, minmax(11rem, 1fr)) */}
  <StatTile
    label="Bugün giren kişi"
    value={today}
    unit="kişi"
    change={percentChange(today, yesterday)}   // önceki 0/yoksa null -> uydurma yüzde yazılmaz
    compareLabel="dünden"                        // "dünden %22 fazla"
    spark={last7Days}                            // eskiden yeniye
    loading={q.isLoading}
    error={q.isError}
    onRetry={() => q.refetch()}
  />
  <StatTile label="Açık şikâyet" value={open} change={percentChange(open, lastWeek)}
            goodWhen="down" compareLabel="geçen haftaya göre" />   {/* artış KÖTÜ: kırmızı */}
</div>
```

`goodWhen`: `up` (varsayılan, artış iyi), `down` (düşüş iyi: şikâyet, hata, bekleyen), `neutral` (renk yok).
Renk tek başına anlam taşımaz: ok simgesi + cümle + ekran okuyucuya "Bu iyi bir gelişme / Dikkat edilmesi gerekiyor".

### Grafik paneli (başlık + tek cümle yorum + grafik + tablo alternatifi)

```tsx
import { ChartPanel, LineAreaChart } from '../../components/charts';
import { compareSentence, useCompareSentence } from '../../components/ui';

const sentence = useCompareSentence();
const { parts, tone } = sentence({ nowLabel: 'Bugün', current: 120, thenLabel: 'dün', previous: 98,
                                   unit: 'kişi', verb: 'girdi' });
// "Bugün 120 kişi girdi, dün 98 idi: %22 fazla"

<ChartPanel
  title="Her gün kaç kişi girdi?"
  insight={parts} insightTone={tone}
  loading={q.isLoading} error={q.isError} onRetry={q.refetch}
  empty={q.data?.length === 0}
  table={{ columns: [{ key: 'day', header: 'Gün' }, { key: 'n', header: 'Kişi', align: 'end' }],
           rows: q.data.map((d) => ({ day: formatDate(d.day), n: formatNumber(d.n) })) }}
  footnote="Her gece yenilenir."
>
  <LineAreaChart data={q.data} xKey="day" series={[{ key: 'n', label: 'Giren kişi' }]}
                 ariaLabel="Günlük giren kişi sayısı" />
</ChartPanel>
```

- Yorum `aria-live` DEĞİLDİR; grafik (`role="img"`) ona `aria-describedby` ile bağlanır (ChartPanel bağı kurar, `ChartFrame` ve `FunnelChart` okur).
- "Veriyi tablo olarak göster" düğmesi `aria-expanded/aria-controls` taşır; tablo kaydırmalı kap içindedir.
- Sayfa kendi grafiğini `ChartPanel` olmadan da kullanabilir; o zaman kendi `Insight`'ını koyup `describedBy` bağını kurmaz (önerilmez).

### Halka, sıralı çubuk, durum, açıklama

```tsx
<ProgressRing value={verified} max={registered} label="kişi e-postasını doğruladı" tone="success" />

<RankedBars
  ariaLabel="En çok mesajlaşılan 5 sohbet"
  items={rows.map((r) => ({ key: r.id, label: r.name, value: r.count, hint: r.faculty }))}
  limit={5} showShare formatValue={(n) => `${n} mesaj`}   // order="asc": en az olanlar üstte
/>

<StatusDot tone="success">Mail kuyruğu çalışıyor</StatusDot>   {/* success|warning|danger|info|primary|neutral */}
<StatusDot tone="danger">3 mail gönderilemedi</StatusDot>

<ChartLegend items={[{ key: 'k', label: 'Kayıt' }, { key: 'g', label: 'Giriş' }]} />  {/* renk + desen + metin */}
```

`StatusDot` ton adını ekran okuyucuya ("Sorun yok:") okutur; her tonun simgesi farklıdır
(onay / üçgen / çarpı / i / nokta). Grafik içi renk dolguları Recharts'ındır; aynı grafiğin yanındaki `ChartLegend` serileri
ayrıca desenle ve metinle ayırt eder (grafik çizgisine desen uygulanmaz: gerekiyorsa `ChartPanel.table` ile veriyi tablo olarak verin).

### Mobilde tablo

```tsx
import { ResponsiveTable } from '../../components/ui';          // Table ile AYNI props + cards/breakpoint
const columns: Column<User>[] = [
  { key: 'name',  header: 'Ad',     card: { priority: 1 } },      // kart başlığı
  { key: 'email', header: 'E-posta', card: { priority: 2 } },     // başlığın altı
  { key: 'role',  header: 'Rol',    card: { priority: 3 }, render: (u) => <Badge>{u.role}</Badge> },
  { key: 'joined', header: 'Katıldı' },                           // "Diğer bilgiler (N)" altında
  { key: 'act', header: '', card: { actions: true }, render: (u) => <Button>Aç</Button> },  // kartın altı, 44 px
];
<ResponsiveTable columns={columns} rows={rows} rowKey={(u) => u.id} caption="Kullanıcılar" />
```

- 640 px altında kart yığını, üstünde normal `Table` (selection, sıralama, onRowClick, yükleniyor/boş/hata aynen).
- `card` ipucu yoksa ilk 3 sütun kartın üstünde olur. Kartta sıralama için "Sırala" seçici + yön düğmesi çıkar.
- Mevcut `Table` kullanan sayfalar etkilenmez; geçiş için yalnız bileşen adını değiştirmek ve (isteğe bağlı) `card` ipuçları eklemek yeter.
- Başka kart yığını gerekirse `DataCards` doğrudan kullanılabilir.
- Hâlâ tablo kalacaksa (çok sütunlu rapor): `<ScrollShadow ariaLabel="…"><Table … /></ScrollShadow>` — yatay kayar, kenarda gölge çıkar, "yana kaydırın" ipucu verir.

```tsx
const narrow = useIsNarrow();            // < 640 px; matchMedia yoksa false (SSR/test güvenli)
<ActionBar align="end"><Button>Dışa aktar</Button><Button>Yenile</Button></ActionBar>   // sarar, dar ekranda 44 px
```

`PageHeader` telefonda artık başlık ve eylemleri alt alta dizer (eylem düğmeleri satırı doldurur, 44 px).

### Sayı ve süre

```tsx
const f = useKitFormat();
f.compact(12400)        // "12,4 B"      (B = bin, Mn = milyon, Mr = milyar, Tn = trilyon)
f.compact(1_200_000)    // "1,2 Mn"
f.percent(12.5, 1)      // "%12,5"
f.relative(date)        // "Az önce" | "3 dk önce" | "2 sa önce" | "Dün" | "5 gün önce" | 30 günden eskiyse tarih
```

## "Çocuk bile anlasın" yazım kuralları

1. **Tek cümle, günlük dil, sayı önde.** Başlık bir soru ya da kısa ad olsun; yorum, neyin ne kadar olduğunu ve iyi mi kötü mü olduğunu söylesin.
2. **Teknik terim yok.** Zorunluysa ilk geçtiği yerde parantezle açıkla.
3. **Rengi tek başına kullanma.** Renk + simge + metin (+ grafikte desen). Durumu hep kelimeyle de yaz ("Sorun var", "Dikkat").
4. **Karar gerektiren yerde sonucu söyle.** Düğme adı eylemi anlatsın ("Bu kişiyi engelle"), onay penceresi ne olacağını yazsın ("Bu kişi artık giriş yapamaz. İstediğiniz zaman kaldırabilirsiniz.").
5. **Uydurma sayı yok.** Karşılaştırılacak eski değer 0 ya da yoksa yüzde yazma ("dün hiç yoktu" / karşılaştırma yok).
6. **Boş, yükleniyor, hata cümleleri insan gibi olsun**: "Henüz veri yok." / "Grafik yükleniyor…" / "Bu bilgi şu an yüklenemedi." + "Tekrar dene".
7. Büyük sayıları kısalt (`12,4 B`), ama tam sayı ipucuyla veya tabloda da göster.
8. Birimi sayıdan ayrı yaz ("120 kişi", "45 mesaj", "3 dk"); kısaltma kullanma.

### Cümle şablonları

| Durum | Şablon | Örnek |
|---|---|---|
| Karşılaştırma | `{Şimdi} {N} {birim} {eylem}, {önce} {M} idi: %{X} {fazla/az}` | Bugün 120 kişi girdi, dün 98 idi: %22 fazla |
| Önceki sıfır | `{Şimdi} {N} {birim} {eylem}, {önce} hiç yoktu` | Bugün 5 rapor geldi, dün hiç yoktu |
| Pay | `{N} {birim}in {X} tanesi {durum}` / `Her {K} kişiden {J}'i {durum}` | Her 10 kişiden 7'si e-postasını doğruladı |
| En çok | `En çok {şey}: {ad} ({N})` | En çok mesajlaşılan sohbet: Bilgisayar Kulübü (320 mesaj) |
| Kuyruk/sistem | `{Şey} şu an {durum}` | Mail kuyruğu şu an çalışıyor / 3 mail bekliyor |
| Bekleyen iş | `{N} {şey} senin onayını bekliyor` | 4 etkinlik senin onayını bekliyor |
| Sakin | `Her şey yolunda: {neden}` | Her şey yolunda: bekleyen şikâyet yok |

### Teknik terim sözlüğü

| Teknik | Panelde yaz |
|---|---|
| DAU / günlük aktif kullanıcı | Bugün giren kişi |
| WAU | Bu hafta giren kişi |
| MAU | Bu ay giren kişi |
| Retention / tutundurma | Geri dönen kişi |
| Churn | Bırakan kişi |
| Cohort / kohort | Aynı gün katılan kişiler |
| Funnel / dönüşüm hunisi | Adım adım kaç kişi geldi |
| Conversion rate | Kaç kişi sonuna kadar gitti |
| Engagement | Ne kadar kullanıldı |
| Session / oturum | Giriş (bir kez girip çıkma) |
| Active session | Şu an açık giriş |
| Impression / gösterim | Kaç kez görüldü |
| Click-through / CTR | Görenlerden kaç kişi tıkladı |
| Delivery rate | Ulaşan bildirim oranı |
| Bounce (e-posta) | Geri dönen (ulaşmayan) e-posta |
| Queue / kuyruk | Sıra bekleyen işler |
| Dead letter / DEAD | Defalarca denendi, gönderilemedi |
| Retry | Yeniden deneme |
| Throttle / rate limit | Çok hızlı istek sınırı |
| Latency / p95 | Cevap süresi (en yavaş %5'te) |
| Uptime | Kesintisiz çalışma süresi |
| Token (push) | Bildirim alan cihaz |
| Audit log | Kim ne yaptı kaydı |
| Moderation | İçerik denetimi |
| Suspend | Hesabı askıya al (geçici durdur) |
| Anonymize | Kişisel bilgileri sil |
| Idempotency | (kullanıcıya gösterme) |
| RBAC / izin profili | Bu yöneticinin yapabilecekleri |
| Payload / endpoint | (kullanıcıya gösterme) |

## Erişilebilirlik özeti

- Her bileşen: etiketli `role` (`group`, `progressbar`, `list`, `region`), klavye ile ulaşılabilir kaydırma/ipucu, 44 px hedef (dar ekranda).
- Hareket: ilerleme halkası, çubuk uzaması ve nabız `prefers-reduced-motion`'da kapanır (`styles/global.css` kuralı).
- Renk: tüm vurgular `--success/--danger/--warning/--info/--primary/--chart-*` değişkenlerinden gelir; koyu temada otomatik değişir.
- Test: `ui/kit.test.tsx`, `charts/ChartPanel.test.tsx`.
