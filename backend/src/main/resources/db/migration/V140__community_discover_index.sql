-- Kesfet kategori sayimi / filtresi: ACTIVE + PUBLIC kulupler kategoriye gore.
CREATE INDEX idx_community_discover_category ON community (status, visibility, category);
