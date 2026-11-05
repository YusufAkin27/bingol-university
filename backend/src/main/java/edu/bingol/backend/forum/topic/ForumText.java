package edu.bingol.backend.forum.topic;

import java.util.regex.Pattern;

/**
 * Forum metin temizligi (XSS / gorunmez karakter): kontrol ve bidi/sifir genislik karakterleri atilir, HTML etiketleri
 * silinir. Cikti JSON duz metindir; istemci HTML yorumlamaz, bu temizlik ikinci savunma hattidir.
 */
public final class ForumText {

    private static final Pattern HTML_TAG = Pattern.compile("</?[a-zA-Z!][^>]*>");
    private static final Pattern MANY_NEWLINES = Pattern.compile("\\n{3,}");
    private static final Pattern SPACES = Pattern.compile("[ \\t\\u00A0]+");

    private ForumText() {}

    /** Tek satir (baslik): tum bosluklar tek bosluga iner. */
    public static String line(String s) {
        if (s == null) {
            return "";
        }
        return SPACES.matcher(strip(s).replace('\n', ' ')).replaceAll(" ").strip();
    }

    /** Cok satirli govde: satir sonlari korunur, art arda 3+ bos satir 2'ye iner. */
    public static String block(String s) {
        if (s == null) {
            return "";
        }
        String t = strip(s).replace("\r\n", "\n").replace('\r', '\n');
        StringBuilder out = new StringBuilder();
        for (String ln : t.split("\n", -1)) {
            out.append(SPACES.matcher(ln).replaceAll(" ").stripTrailing()).append('\n');
        }
        return MANY_NEWLINES.matcher(out.toString()).replaceAll("\n\n").strip();
    }

    private static String strip(String s) {
        String noTags = HTML_TAG.matcher(s).replaceAll("");
        StringBuilder sb = new StringBuilder(noTags.length());
        for (int i = 0; i < noTags.length(); i++) {
            char c = noTags.charAt(i);
            if (c == '\n' || c == '\r' || c == '\t') {
                sb.append(c);
            } else if (Character.isISOControl(c) || (c >= '​' && c <= '‏') || (c >= '‪' && c <= '‮')
                    || (c >= '⁦' && c <= '⁩') || c == '﻿' || c == ' ' || c == ' ') {
                continue;
            } else {
                sb.append(c);
            }
        }
        return sb.toString();
    }

    /** Kart onizlemesi: bosluklar sadelesir, en cok {@code max} karakter, kesilirse '…' eklenir. */
    public static String preview(String body, int max) {
        String flat = SPACES.matcher((body == null ? "" : body).replace('\n', ' ')).replaceAll(" ").strip();
        if (flat.length() <= max) {
            return flat;
        }
        int cut = max - 1;
        int sp = flat.lastIndexOf(' ', cut);
        if (sp > max / 2) {
            cut = sp;
        }
        return flat.substring(0, cut).stripTrailing() + "…";
    }
}
