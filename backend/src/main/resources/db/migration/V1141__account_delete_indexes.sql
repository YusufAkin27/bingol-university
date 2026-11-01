-- FIX-P08 (A09#14): hesap silmede (AccountDataPurger) user_id / author_id ile calisan sorgular bu tablolarda
-- sirali tarama yapiyordu (PK/UNIQUE sutunlari baska sirada). Ek olarak ders silinirken tt_exam.course_id taranir.
-- Geriye uyumlu, yalniz indeks; onek acc1141_ (indeks adlari tum semada benzersizdir).
CREATE INDEX IF NOT EXISTS acc1141_feedback_vote_user ON feedback_vote (user_id);
CREATE INDEX IF NOT EXISTS acc1141_event_feedback_user ON event_feedback (user_id);
CREATE INDEX IF NOT EXISTS acc1141_support_msg_author ON support_message (author_id) WHERE author_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS acc1141_tt_exam_course ON tt_exam (course_id) WHERE course_id IS NOT NULL;
