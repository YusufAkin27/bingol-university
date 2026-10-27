-- Ana sayfa one cikan etkinlik: ACTIVE etkinlikler en cok GOING, sonra en yakin baslangic sirasiyla.
CREATE INDEX idx_event_featured_going ON user_event (going_count DESC, starts_at, id) WHERE status = 'ACTIVE';
