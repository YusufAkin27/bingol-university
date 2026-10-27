package edu.bingol.backend.notification.outbox;

/** Kuyruga yeni push yazildi (commit sonrasi isleyiciyi uyandirir). */
public record PushQueued(int count) {
}
