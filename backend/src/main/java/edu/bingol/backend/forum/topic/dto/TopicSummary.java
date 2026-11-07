package edu.bingol.backend.forum.topic.dto;

import java.time.Instant;

/** Liste/akis karti (sozlesme A: TopicSummary). Alan adlari sozlesmeyle birebir. */
public record TopicSummary(Long id, String title, String bodyPreview, CategoryRef category, Author author,
                           Instant createdAt, Instant editedAt, int likeCount, int commentCount, boolean likedByMe,
                           boolean savedByMe, boolean followedByMe, ImageView thumbnail, int imageCount,
                           boolean hasPoll, boolean pinned, boolean locked, boolean mine, boolean canModerate,
                           String status) {}
