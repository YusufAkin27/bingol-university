-- Hesap silme ve FK aramalari icin kismi indeksler (V995 kvk9_* ornegi: yalniz dolu satirlar). Onek ak1900_.
CREATE INDEX ak1900_att_marked_by_idx ON ac_attendance (marked_by) WHERE marked_by IS NOT NULL;
CREATE INDEX ak1900_att_revoked_by_idx ON ac_attendance (revoked_by) WHERE revoked_by IS NOT NULL;
CREATE INDEX ak1900_scanreq_student_idx ON ac_scan_request (student_id);
CREATE INDEX ak1900_scanreq_decided_by_idx ON ac_scan_request (decided_by) WHERE decided_by IS NOT NULL;
CREATE INDEX ak1900_notice_created_by_idx ON ac_notice (created_by) WHERE created_by IS NOT NULL;
CREATE INDEX ak1900_nfile_uploaded_by_idx ON ac_notice_file (uploaded_by) WHERE uploaded_by IS NOT NULL;
CREATE INDEX ak1900_academician_reviewed_by_idx ON academician (reviewed_by) WHERE reviewed_by IS NOT NULL;
