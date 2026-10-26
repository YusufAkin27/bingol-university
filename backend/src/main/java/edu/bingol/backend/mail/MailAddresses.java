package edu.bingol.backend.mail;

/** E-posta adresi yardimcilari. */
final class MailAddresses {

    private MailAddresses() {
    }

    /** Log icin maskeler: "ali.veli@bingol.edu.tr" -> "a***@bingol.edu.tr". */
    static String mask(String address) {
        if (address == null || address.isBlank()) {
            return "?";
        }
        int at = address.indexOf('@');
        if (at < 1) {
            return "***";
        }
        return address.charAt(0) + "***" + address.substring(at);
    }

    /** Bos olmayan, makul uzunlukta, satir sonu icermeyen ve tek '@' iceren adres (baslik enjeksiyonu onlemi). */
    static boolean isPlausible(String address) {
        if (address == null || address.isBlank() || address.length() > 254) {
            return false;
        }
        int at = address.indexOf('@');
        return at > 0 && at == address.lastIndexOf('@') && at < address.length() - 1
                && address.chars().noneMatch(c -> c <= ' ' || c == ',' || c == ';' || c == '<' || c == '>');
    }
}
