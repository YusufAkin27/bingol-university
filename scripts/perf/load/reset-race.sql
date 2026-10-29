-- C2 yaris testini yeniden kosulabilir yapar: kapasite etkinligini 90/100'e, ilk anketi 0 oya dondurur.
DELETE FROM event_rsvp WHERE event_id = (SELECT id FROM user_event WHERE title = 'ldx Kapasite Yarisi')
  AND user_id NOT IN (SELECT id FROM (SELECT id, row_number() OVER (ORDER BY id) n FROM app_user WHERE email LIKE 'seed%@bingol.edu.tr') s WHERE n BETWEEN 2000 AND 2089);
UPDATE user_event SET going_count = (SELECT count(*) FROM event_rsvp WHERE event_id = user_event.id AND status = 'GOING') WHERE title = 'ldx Kapasite Yarisi';
DELETE FROM poll_vote WHERE poll_id = (SELECT min(id) FROM poll WHERE title LIKE 'ldx Anket %');
DELETE FROM poll_ballot WHERE poll_id = (SELECT min(id) FROM poll WHERE title LIKE 'ldx Anket %');
UPDATE poll_option SET vote_count = 0, rank_score = 0 WHERE poll_id = (SELECT min(id) FROM poll WHERE title LIKE 'ldx Anket %');
UPDATE poll SET voter_count = 0 WHERE id = (SELECT min(id) FROM poll WHERE title LIKE 'ldx Anket %');
