-- FIX-P05 (A05#5): etkinlik liste/one cikan sorgulari "ends_at >= simdi" kosuluyla kayan etkinlikleri arar.
-- Kismi indeks yalniz ACTIVE etkinlikleri kapsar (kucuk, geri donusu kolay; veri degismez).
CREATE INDEX evt1110_active_ends ON user_event (ends_at) WHERE status = 'ACTIVE';
