-- Kulup uye aramasi lower(display_name) LIKE kullanir; V59'daki ham sutun indeksi bunu karsilamaz.
-- (Ham sutun uzerindeki ILIKE aramalari icin idx_perf_user_name_trgm zaten var; tekrar eklenmedi.)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX prf190_user_display_trgm ON app_user USING GIN (lower(display_name) gin_trgm_ops);
