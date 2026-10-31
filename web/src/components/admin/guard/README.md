# Yönetim paneli ortak güvenlik bileşenleri (`components/admin/guard`)

Amaç: yönetim panelinde kimse yanlışlıkla geri alınamaz bir işlem yapmasın. Bu klasördeki bileşenler
`components/ui` üzerinden de dışa aktarılır (`import { GuardedAction } from '../../components/ui'`).
**Yönetim paneli yalnız Türkçedir:** metinler `i18n/tr/admin-guard.ts` içindedir; en/ar çevirisi yazılmaz
(`i18n/index.ts` en/ar sözlüklerine aynı Türkçe metni katar, `scripts/check-i18n.mjs` bu dosyayı en/ar eşitliğinden
`TR_ONLY` listesiyle muaf tutar).

## Hangi eylemde hangi bileşen

| Eylem | Kullanın |
|---|---|
| Kullanıcı silme / rol değiştirme / askıya alma | `GuardedAction danger typeToConfirm={user.email} requireReason irreversible` |
| Toplu gönderim (push, e-posta kampanyası), toplu silme | `GuardedAction impact={{count, noun}}` (eşik üstü sayıyı yazdırır); sebep gerekiyorsa `requireReason` |
| Sözleşme yayınlama | `GuardedAction typeToConfirm={'YAYINLA v' + version}` |
| Kritik ayar anahtarı | `GuardedAction` + `message`/`consequence` içinde eski → yeni değer farkı (örn. `<Diff before after/>`) |
| Geri alınabilir, düşük riskli onay | `ConfirmDialog` (`consequence` + `irreversible={false}` ile) |
| Form kaydedilmeden çıkış | `useUnsavedGuard(dirty)` |
| Bir kaydın geçmişi | `<AuditTrail targetType targetId />` |

## Bileşenler ve API

### `GuardedAction` (düğme + diyalog + sebep + yazarak onay + mutation)

```tsx
<GuardedAction
  danger
  irreversible
  title="Kullanıcıyı sil"
  consequence="Hesap anonimleştirilir; mesajlar ve etkinlik kayıtları kalır."
  typeToConfirm={user.email}
  requireReason
  reasonTemplates={reportTemplatesToOptions(templates, i18n)}
  invalidateKeys={[['admin', 'users']]}
  successMessage="Kullanıcı silindi"
  onConfirm={({ reason, idempotencyKey }) =>
    api.del(`/admin/users/${user.id}?reason=${encodeURIComponent(reason)}`, idempotencyHeaders(idempotencyKey))
  }
>
  Sil
</GuardedAction>
```

| Prop | Tür | Not |
|---|---|---|
| `children` | `ReactNode` | düğme etiketi |
| `title` | `string` | diyalog başlığı (zorunlu) |
| `onConfirm` | `({reason, idempotencyKey}) => Promise` | hata fırlatırsa toast + diyalog açık kalır |
| `message`, `consequence` | `ReactNode` | açıklama / "ne olacak" |
| `irreversible` | `boolean` | `true` kırmızı "geri alınamaz", `false` "geri alınabilir", verilmezse satır yok |
| `danger` | `boolean` | kırmızı düğme, `role="alertdialog"`, alan yoksa ilk odak Vazgeç |
| `requireReason`, `reasonMinLength` (10), `reasonLabel`, `reasonTemplates` | | sebep alanı |
| `typeToConfirm` | `string` | yazdırılacak metin |
| `impact` | `{count, threshold?=50, noun?}` | `count > threshold` ise sayıyı yazdırır |
| `successMessage` (`false` sessiz), `errorMessage`, `invalidateKeys`, `onSuccess` | | `useGuardedMutation` ayarları |
| `variant`, `size`, `leftIcon`, `fullWidth`, `disabled`, `className` | | tetikleyici düğme |

Davranış: onay düğmesi yalnız tüm koşullar sağlanınca açılır; iş sürerken diyalog Esc/dış tıklama/Vazgeç ile
kapanmaz; ikinci tetikleme yok sayılır; her açılışta yeni `Idempotency-Key` üretilir. Odak ilk alana
(sebep → yazarak onay → toplu sayı) gelir; Enter, yazarak onay alanı eşleşmişse onaylar.

### `TypeToConfirm`

`target`, `value`, `onChange(value, matches)`, `label?`, `focusOnMount?`, `disabled?`, `onEnter?`.
Karşılaştırma `matchesTarget` ile: Türkçe İ/ı katlaması (`SİL` = `sil` = `SIL` = `Sıl`), büyük/küçük harf ve
baş/son boşluk yok sayılır, ş/ğ/ü/ö/ç ayrımı korunur. Yapıştırma serbesttir.

### `ReasonField`

`value`, `onChange`, `minLength` (10), `maxLength` (en çok 300), `label?`, `templates?: ReasonTemplateOption[]`,
`focusOnMount?`, `disabled?`, `required?`. Karakter sayacı, kısa sebep uyarısı (`role="alert"`), hazır sebep
düğmeleri. Rapor modülünün şablonları (`GET /admin/reports/reason-templates`, `reports/ReasonFields.tsx` bunları
kullanır, o dosya değişmedi) `reportTemplatesToOptions(templates, i18n)` ile dönüştürülür.

### `BulkImpactNotice`

`count`, `threshold` (50), `noun?`, `value`, `onChange(value, confirmed)`, `focusOnMount?`. "N kayıt etkilenecek"
şeridi; `count > threshold` ise `String(count)` yazdırır. Bileşensiz kontrol için `isBulkConfirmed(count, threshold, typed)`.

### `useGuardedMutation`

```ts
const g = useGuardedMutation<Data, Vars>({
  mutationFn: (vars, { idempotencyKey }) => api.post('/admin/x', vars, idempotencyHeaders(idempotencyKey)),
  successMessage: 'Kaydedildi', // veya (data, vars) => string, ya da false
  invalidateKeys: [['admin', 'x']],
});
const res = await g.run(vars); // { ok: true, data } | { ok: false, error?, skipped? } — asla fırlatmaz
g.isPending; g.renewKey(); // yeni onay diyaloğu açarken
```

İş sürerken `run` çağrıları **senkron ref kilidiyle** yok sayılır (`skipped: true`); yalnız düğmeyi devre dışı
bırakmak çift tetiklemeyi (Enter + tık) önlemez. Anahtar: hatadan sonra yeniden denemede aynı, başarıdan sonra
yeni. `api.post/put/patch/del` artık son bağımsız değişken olarak `{ headers }` kabul eder; `idempotencyHeaders(key)`
bunu üretir. Backend desteği P04'te gelir; o zamana dek başlık zararsızdır.

### `adminError(i18n, err, ...kapsamlar)` (`lib/errors.ts`)

Tek hata metni yardımcısı: `admin.err.<KOD>` (ya da verilen kapsamlar) → `common.error.<KOD>` → sunucu mesajı →
genel. Eski `adminErrorMessage` (campaigns/shared) bunun takma adıdır; `errorMessage` aynen durur.

### `useUnsavedGuard(dirty)`

`const { dialog, confirmLeave } = useUnsavedGuard(dirty)`; `{dialog}` sayfaya konur. `dirty` iken `beforeunload`
uyarısı ve uygulama içi bağlantı tıklamaları için "Kaydedilmemiş değişiklikler var" diyaloğu. Uygulama
`BrowserRouter` kullandığından `useBlocker` kullanılamaz; tarayıcı geri düğmesi kapsam dışıdır, programatik
çıkışta `confirmLeave(() => navigate(...))` kullanın.

### `AuditTrail`

`targetType`, `targetId`, `size?` (20), `title?`. `GET /api/admin/audit?targetType=&targetId=&size=` çağırır
(sunucu tarafı P02'de eklenir); 404/501 ve boş liste "Denetim kaydı henüz yok" gösterir. Satır alanları:
`adminEmail`, `action` (yoksa `method path`), `reason`, `at`.

### `ConfirmDialog` genişletmesi (`components/ui/Overlay.tsx`, geriye uyumlu)

Yeni isteğe bağlı prop'lar: `consequence`, `irreversible`, `children` (ek alanlar), `confirmDisabled`,
`role` (`'dialog'` | `'alertdialog'`), `initialFocus` (`'confirm'` | `'cancel'` | `'content'`). `Modal`/`Drawer`
ayrıca `role` ve `describedBy` kabul eder. Mevcut kullanımlar değişmez.

## Erişilebilirlik

Odak tuzağı ve Esc `useFocusTrap` ile; `aria-labelledby` + `aria-describedby` (mesaj + sonuç notu); yıkıcı
eylemlerde `role="alertdialog"`; alan durumları `aria-live`/`role="alert"` ile duyurulur; kapanınca odak
tetikleyiciye döner. Testler: `guard.test.tsx`.

## W1-B sunucu sertleştirmesi (gerekçe, yol, süzgeç)

- Sebep >= 5 karakter (`ADMIN_REASON_MIN`) ayar, kullanıcı (askı/engel/doğrulama/şifre sıfırlama/oturum), gönderi/haber,
  kampanya, erişim engeli, itiraz kararı işlemlerinde zorunludur; sohbet içeriği açan uçlarda >= 20
  (`CHAT_CONTENT_REASON_MIN`). `guardHeaders` kontrol karakterini (satır sonu, sekme) boşluğa çevirir
  (`cleanReason`); `ReasonField` yazarken aynısını yapar. Sunucu aksi halde 400 `REASON_INVALID` verir.
- `/api/admin/**` yoluna konan parça `adminSeg(değer)` ile kodlanır: yalnız `%40` (e-posta `@`) kabul edilir, `/` ya da
  boşluk gibi `%xx` üreten değer istemcide 400 `ADMIN_PATH_INVALID` ile reddedilir (sunucu filtresiyle aynı kural).
- Yeni izin `users.verify` (yalnız FULL): "E-postayı elle doğrula" ve bekleyen kaydı doğrulama düğmeleri bunu ister.
