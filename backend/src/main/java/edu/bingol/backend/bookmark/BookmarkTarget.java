package edu.bingol.backend.bookmark;

/**
 * Genel "bookmark" tablosuna yazilan hedef turleri (target_type VARCHAR(16), CHECK yok: sema degismez).
 * Gonderi (post_save) ve forum (forum_bookmark) kendi tablolarinda kalir; birlesik listede okuma birlestirmesiyle gorunur.
 */
public enum BookmarkTarget { NEWS, EVENT, COMMUNITY, POLL, ACADEMIC }
