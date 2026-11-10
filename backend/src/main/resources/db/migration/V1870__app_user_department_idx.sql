-- Bolum sohbeti "bolum ara" (keyset + DISTINCT/GROUP BY app_user.department, yalniz ACTIVE) icin kismi indeks.
-- Onek au1870_. CONCURRENTLY Flyway islemi icinde calisamaz: duz IF NOT EXISTS (kullanici tablosu kucuk; kisa yazma kilidi).
CREATE INDEX IF NOT EXISTS au1870_app_user_dept_active ON app_user (department) WHERE status = 'ACTIVE' AND department IS NOT NULL;
