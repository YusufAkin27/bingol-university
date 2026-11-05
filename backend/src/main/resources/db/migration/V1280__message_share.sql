-- V1280: sohbet mesajiyla ICERIK PAYLASIMI (SH-BE). Mesaj, gonderi/reel/haber/etkinlige referans tasir; baslik, gorsel ve
-- kullanilabilirlik OKUMA ANINDA goruntuleyene gore hesaplanir (siliniyorsa/gizliyse/alici goremiyorsa "kullanilamaz"),
-- bu yuzden burada icerik kopyasi YOKTUR. Kullanici kimligi tutan sutun eklenmez (AccountDataPurgerCoverageTest etkilenmez).
-- share_type: POST | REEL | NEWS | EVENT. Her ikisi birden dolu ya da birden bos olur; mevcut satirlar NULL kalir.
-- Sutunlar bos (NULL) eklendigi icin tablo yeniden yazilmaz ve taranmaz (PostgreSQL 11+); indeks gerekmez (referansla sorgu yok).
ALTER TABLE message ADD COLUMN share_type VARCHAR(8);
ALTER TABLE message ADD COLUMN share_ref_id BIGINT;
