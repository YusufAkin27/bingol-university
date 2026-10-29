# Backend istekleri (mobil tasarim uygulamasindan)

Mobil alanlari bu uclar gelene dek opsiyonel okur.

- K8 / anket liste: Liste ogelerinde `results`/`average` yalniz `resultsVisible` iken dolu geliyor (yeterli); "Katildiklarim" ve "Kapanan" sekmelerinde toplam kayit sayisi (`total`) olmadigindan "N anket arsivde" sayisi yalniz tum sayfalar yuklendiginde gosteriliyor. Istek: `GET /api/polls?scope=` yanitina opsiyonel `totalCount` ve acik anket sayisi (sekme rozeti) eklenmesi.
- K8 / anket kulup: Kulup anket listesi bos kutusunda kulup adi cipi icin liste yanitinda `communityName` yeterli degil (bos liste); kulup detayindan gecirilecek (K7).
