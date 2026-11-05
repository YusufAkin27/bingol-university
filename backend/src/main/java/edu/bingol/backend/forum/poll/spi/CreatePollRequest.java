package edu.bingol.backend.forum.poll.spi;

import java.time.Instant;
import java.util.List;

/**
 * Konu olusturma govdesindeki {@code poll} nesnesi: {@code {question?, options:[2..6 metin], endsAt?, allowChangeVote}}.
 */
public record CreatePollRequest(String question, List<String> options, Instant endsAt, boolean allowChangeVote) {}
