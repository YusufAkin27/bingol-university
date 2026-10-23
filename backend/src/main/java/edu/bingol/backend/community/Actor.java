package edu.bingol.backend.community;

import edu.bingol.backend.common.CurrentUser;

/** Istegi yapan kisi: kullanici id'si + sistem yoneticisi mi. Servisler SecurityContext'e degil buna bakar (test edilebilirlik). */
public record Actor(Long id, boolean admin) {

    public static Actor current() {
        return new Actor(CurrentUser.id(), CurrentUser.isAdmin());
    }
}
