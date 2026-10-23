package edu.bingol.backend.search;

import java.util.List;

/**
 * Genel aramaya katilan bir icerik turu. Haber, topluluk ve etkinlik modulleri kendi turleri icin bunu
 * bean olarak uygular; SearchService tum provider'lari otomatik toplar.
 */
public interface SearchProvider {

    SearchType type();

    /** En alakali sonuclar (en fazla limit adet). q en az 2 karakterdir ve ham kullanici girdisidir (parametreli sorgu kullanin). */
    List<SearchHit> search(String q, int limit);
}
