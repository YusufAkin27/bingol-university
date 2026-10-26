package edu.bingol.backend.mail;

/** Kuyruktaki e-postanin durumu. FAILED = en az bir deneme basarisiz, yeniden denenecek. */
public enum MailStatus { PENDING, SENT, FAILED, DEAD }
