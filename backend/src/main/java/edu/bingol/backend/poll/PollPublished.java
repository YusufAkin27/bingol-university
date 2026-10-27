package edu.bingol.backend.poll;

/** Anket yayinlandi (acik duruma gecti); commit sonrasi "anket acildi" bildirimi tetiklenir. */
public record PollPublished(Long pollId) {
}
