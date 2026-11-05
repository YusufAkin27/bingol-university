package edu.bingol.backend.forum.topic.dto;

/** Konu gorseli: {@code url} tam, {@code thumbUrl} onizleme (ikisi de oturumlu /api/forum/media/{id}). */
public record ImageView(Long id, String url, String thumbUrl, Integer width, Integer height) {}
