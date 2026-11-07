package edu.bingol.backend.forum.notify;

/** Ayni olay icin ayni aliciya ikinci bildirimi onleyen kalici defter (V1440 forum_notify_seen). */
public interface ForumNotifyLedger {

    /**
     * (tur, hedef, eden, alici) ilk kez goruluyorsa kaydeder ve true doner; daha once goruldu ise false (bildirim
     * gitmez). Eszamanli iki cagri icin yalniz biri true alir.
     */
    boolean firstTime(String kind, long targetId, long actorId, long recipientId);
}
