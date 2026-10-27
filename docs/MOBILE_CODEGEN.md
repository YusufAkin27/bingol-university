# OpenAPI'den istemci üretimi (web + mobil)

Kaynak gerçek: `docs/openapi.json` (springdoc, `/v3/api-docs`; yalnız ADMIN, üretimde kapalı).

## Belgeyi üretmek

```bash
scripts/openapi-export.sh           # canlı backend varsa openapi-gen.js, yoksa Docker Maven + OpenApiExportTest
scripts/openapi-export.sh --check   # commit'teki belgeyle yol/işlem kümesi eşleşiyor mu (CI; fark varsa 1)
node scripts/openapi-check.js       # canlı sunucuya karşı sözleşme testi (DRIFT=0 ile sürüm kayması atlanır)
```

Bilinen sınır: yeni uçlar (gönderiler, küfür listesi, anketler...) belge yeniden üretilene kadar şemada olmaz;
yeni özellik birleşince `openapi-export.sh` çalıştırılıp `docs/openapi.json` commit'lenir, sonra `npm run gen:api`.

## Web (yapıldı)

`cd web && npm run gen:api` -> `src/api/generated/schema.d.ts` (openapi-typescript). `src/api/typed/typedApi.ts`
mevcut `client.ts` üstünde tip güvenli `typedGet/typedSend` sağlar (yol, sorgu, gövde, yanıt şemadan çıkar).
Elle yazılmış `api/*.ts` modülleri aynen kalır; yeni küçük modüller kademeli olarak `typed/` kullanır.

## Mobil (Dart) seçenekleri

| Seçenek | Artı | Eksi |
|---|---|---|
| `openapi-generator` `dart-dio` | olgun, DTO + istemci, `built_value`/`json_serializable` | büyük çıktı; mevcut tek HTTP katmanını (`core/api.dart`, ETag, tek uçuşlu refresh) atlar; null/`required` farkları |
| `openapi-generator` `dart` (http) | küçük | aynı sorunlar, zayıf tip desteği |
| Yalnız model üretimi (`json_serializable`/`freezed` için şema -> Dart sınıfları) | mevcut `api.dart` korunur; yalnız DTO'lar üretilir | uç sarmalayıcıları elle kalır |

### Öneri

Yalnız modeller üretilsin (`--global-property models,supportingFiles=false`), istemci kodu üretilmesin: mobilde
tek HTTP katmanı (`lib/core/api.dart`: ETag/304 önbelleği, refresh, bakım/hata modeli) bir kural olduğu için
üretilen `dart-dio` istemcisi kullanılmaz. Üretilen modeller `mobile/lib/generated/models/` altına konur
(elle düzenlenmez), mevcut elle yazılmış modeller ekran bazında kademeli değiştirilir; her geçişte `flutter test`
ve FakeBackend JSON'ları `docs/openapi.json` örnekleriyle karşılaştırılır. Springdoc alanları `nullable` üretir
(`?` zorunlu değil), bu yüzden üretilen tipler `String?` olur; ekranlar varsayılan değer verir.

Taslak betik: `scripts/gen-mobile-models.sh` (varsayılan olarak yalnız komutu yazdırır; `RUN=1` ile çalıştırır).
Mobil kodu değiştirmek mobil ajanların alanıdır; bu belge ve betik kod değiştirmez.
