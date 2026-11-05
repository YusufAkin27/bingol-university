package edu.bingol.backend.forum.search;

import com.fasterxml.jackson.annotation.JsonUnwrapped;
import edu.bingol.backend.forum.topic.dto.TopicSummary;

/**
 * Arama sonucu: TopicSummary alanlari DUZ (icice degil) + {@code matchedIn} (TITLE|BODY|COMMENT|CATEGORY) +
 * {@code snippet} (duz metin; BODY/COMMENT eslesmesinde ilgili parca, aksi halde null).
 */
public record ForumSearchItem(@JsonUnwrapped TopicSummary topic, String matchedIn, String snippet) {}
