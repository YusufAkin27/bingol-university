package edu.bingol.backend.moderation.profanity;

import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

/**
 * Guvenli ek zinciri denetimi (yalnizca filtre): Turkce cekim/yapim ekleri ve temel Ingilizce ekler, sadelesmis
 * (ş->s, ğ->g, ü->u, ö->o, ç->c; "ı" ayri). "kok + ek zinciri" sozcuk SONUNA kadar surmeli. Rastgele harf dizisi
 * ek sayilmaz; boylece "klasik" gibi sozcukler kisa kokle eslesmez (Scunthorpe sorunu).
 */
final class Suffixes {

    private Suffixes() {}

    private static final int MAX_PIECES = 4;

    private static final Set<String> PIECES = new HashSet<>(Arrays.asList((
            // cogul / hal / iyelik
            "ler,lar,leri,lari,lerin,larin,lerde,larda,lerden,lardan,lere,lara,lerle,larla,lerim,larim,lerimiz,larimiz,"
            + "i,ı,u,e,a,ye,ya,yi,yı,yu,de,da,te,ta,den,dan,ten,tan,nin,nın,nun,in,ın,un,im,ım,um,imiz,ımız,umuz,"
            + "miz,mız,muz,iniz,ınız,unuz,niz,nız,nuz,si,sı,su,sine,sına,suna,ne,na,ni,nı,nu,nde,nda,nden,ndan,"
            + "yle,yla,le,la,ile,ila,ki,ci,cı,cu,li,lı,lu,lik,lık,luk,ligi,lıgı,lugu,cik,cık,cuk,ca,ce,"
            + "sin,sın,sun,siniz,sınız,sunuz,dir,dır,dur,tir,tır,tur,di,dı,du,ti,tı,tu,dim,dım,dum,tim,tım,tum,"
            + "mis,mıs,mus,ken,yim,yım,yum,iz,ız,uz,ymis,ydi,ydı,cesine,casına,casina,cesi,casi,"
            + "ligim,lıgım,lugum,sız,siz,suz,"
            // yaygin fiil cekimi (yalnizca '+' koklerinde)
            + "mak,mek,ma,me,an,en,ip,ıp,up,erek,arak,ecek,acak,ar,er,ir,ır,ur,yor,iyor,ıyor,uyor"
    ).split(",")));

    private static final Set<String> PIECES_EN = new HashSet<>(Arrays.asList(
            "s,es,ed,d,ing,er,ers,y,ies,ly,est,ness,ish,in,z".split(",")));

    /** {@code t[from..]} bir veya daha fazla (en cok 4) ek parcasindan olusuyor mu? */
    static boolean isChain(String t, int from) {
        return chain(t, from, MAX_PIECES, 2);
    }

    /** mode: 0 = yalnizca Turkce ekler, 1 = yalnizca Ingilizce ekler, 2 = ikisi de (izin kokleri icin). */
    static boolean isChain(String t, int from, int mode) {
        return chain(t, from, mode == 1 ? 2 : MAX_PIECES, mode);
    }

    private static boolean chain(String t, int from, int left, int mode) {
        if (from == t.length()) return true;
        if (left == 0) return false;
        for (int end = from + 1; end <= t.length() && end - from <= 6; end++) {
            String piece = t.substring(from, end);
            boolean ok = (mode != 1 && PIECES.contains(piece)) || (mode != 0 && PIECES_EN.contains(piece));
            if (ok && chain(t, end, left - 1, mode)) return true;
        }
        return false;
    }
}
