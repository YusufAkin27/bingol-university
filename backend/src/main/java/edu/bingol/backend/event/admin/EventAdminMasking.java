package edu.bingol.backend.event.admin;

/** Yonetici ekranlari/CSV icin kisisel veri maskeleme. */
final class EventAdminMasking {

    private EventAdminMasking() {}

    /** "ayse.yilmaz@bingol.edu.tr" -> "a***@bingol.edu.tr"; gecersiz/bos -> null. */
    static String email(String address) {
        if (address == null || address.isBlank()) {
            return null;
        }
        int at = address.lastIndexOf('@');
        if (at <= 0) {
            return "***";
        }
        return address.charAt(0) + "***" + address.substring(at);
    }

    /** Sertifika kodu ipucu: ilk 4 + ... + son 4 (tam kod yonetici ekraninda gosterilmez). */
    static String codeHint(String code) {
        if (code == null || code.length() < 10) {
            return "***";
        }
        return code.substring(0, 4) + "..." + code.substring(code.length() - 4);
    }
}
