package edu.bingol.backend.profile;

/**
 * Profildeki fakulte/bolum/sinif DEGISTI. Commit sonrasi dinleyiciler bolume bagli turetilmis veriyi yeniler
 * (ornegin resmi programdan kopyalanan kisisel ders programi). Dinleyiciler exception sizdirmamalidir.
 */
public record ProfileAcademicChangedEvent(Long userId) {}
