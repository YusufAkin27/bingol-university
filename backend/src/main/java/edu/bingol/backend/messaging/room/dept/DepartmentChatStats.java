package edu.bingol.backend.messaging.room.dept;

/** Bolum odasi ozeti (tek sorguda): uye sayisi ve cagiranin uyeligi. Oda baglantisi yoksa conversationId null. */
public interface DepartmentChatStats {

    String getDeptKey();

    Long getRoomId();

    Long getConversationId();

    Boolean getClosed();

    Long getMemberCount();

    Boolean getJoined();
}
