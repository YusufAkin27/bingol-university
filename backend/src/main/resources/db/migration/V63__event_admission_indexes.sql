-- Bekleme listesi sirasi ve acik etkinlik sayimi icin kismi/ek indeksler (T9)
CREATE INDEX idx_evapp_waitlist ON event_application (event_id, queued_at, id) WHERE status = 'WAITLISTED';
CREATE INDEX idx_event_creator_status ON user_event (created_by, status, ends_at);
