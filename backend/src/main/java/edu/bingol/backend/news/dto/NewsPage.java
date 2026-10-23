package edu.bingol.backend.news.dto;

import java.util.List;

public record NewsPage(List<NewsSummary> items, int page, int totalPages, long totalItems) {
}
