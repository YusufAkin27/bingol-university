package edu.bingol.backend.forum.topic.dto;

import java.util.List;

/** Imecli sayfa (sozlesme: {@code {items, nextCursor}}); imlec opak metindir, null = son sayfa. */
public record ForumPage<T>(List<T> items, String nextCursor) {}
