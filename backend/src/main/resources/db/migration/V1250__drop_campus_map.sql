-- Kampus haritasi ozelligi kaldirildi: V1200 (campus_place, campus_config + cm_* indeks/kisitlari) ve V1201 (tohum)
-- tarafindan olusturulan her sey duser. V1200/V1201 dosyalari CANLIDA uygulanmistir, degistirilmez ve silinmez.
-- Tablolar dusunce ilgili indeksler (cm_place_source_uq, cm_place_list_idx, cm_place_name_idx) ve CHECK kisitlari da gider.
-- Bu ozellik app_setting'e kayit yazmaz (kontrol edildi); medya referans kaynagi (campus_place.photo_key) koddan kalkti.
DROP TABLE IF EXISTS campus_place CASCADE;
DROP TABLE IF EXISTS campus_config CASCADE;
