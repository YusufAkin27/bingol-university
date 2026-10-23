package edu.bingol.backend.moderation;

/** Raporlanabilir icerik turleri. Her tur icin bir {@link ReportTargetHandler} bean'i kayitli olmalidir. */
public enum ReportTargetType { USER, MESSAGE, POST, COMMUNITY, EVENT }
