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

    /**
     * Sayfali arama (tek tur modu): offset kadar atlayip en fazla limit sonuc. Varsayilan uygulama ilk
     * offset+limit sonucu cekip kirpar; buyuk veri setlerinde saglayici OFFSET ile ezmelidir.
     */
    default List<SearchHit> search(String q, int limit, int offset) {
        if (offset <= 0) {
            return search(q, limit);
        }
        List<SearchHit> all = search(q, offset + limit);
        return all.size() <= offset ? List.of() : all.subList(offset, Math.min(all.size(), offset + limit));
    }
}
