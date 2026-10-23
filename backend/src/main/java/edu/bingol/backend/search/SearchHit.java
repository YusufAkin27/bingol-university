package edu.bingol.backend.search;

/**
 * Tek bir arama sonucu. targetId ilgili turun kendi id'sidir (mobil, type'a gore detay ucuna gider).
 * snippet kisa, duz metin ozet (HTML icermez).
 */
public record SearchHit(SearchType type, Long targetId, String title, String snippet, String imageUrl, String date) {
}
