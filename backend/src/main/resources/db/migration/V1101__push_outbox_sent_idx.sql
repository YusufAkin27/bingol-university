-- P04: saglik gostergesi/istatistik "son 24 saatte gonderilen" sayimi (sent_at) icin kismi indeks. Kuyruk tablosunda
-- SENT satirlari 7 gun saklandigi icin onceki sayim tum SENT satirlarini tariyordu. Kismi: yalniz SENT satirlari.
CREATE INDEX ntf1101_push_sent_idx ON push_outbox (sent_at) WHERE status = 'SENT';
