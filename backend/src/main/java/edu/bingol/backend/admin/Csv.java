package edu.bingol.backend.admin;

import java.util.List;

/** Excel/Sheets uyumlu CSV yardimcisi: UTF-8 BOM, CRLF ve CSV (formul) enjeksiyonuna karsi hucre kacirma. */
public final class Csv {

    public static final String BOM = "﻿";
    /** Hucrenin basinda bu karakterlerden biri varsa tablo programi formul sanabilir. */
    private static final String FORMULA_PREFIXES = "=+-@\t\r";

    private Csv() {}

    /** Tek hucre: formul onekleri ' ile etkisizlestirilir; ayirici/tirnak/satir sonu iceren degerler tirnaklanir. */
    public static String cell(Object value) {
        if (value == null) {
            return "";
        }
        String s = value.toString();
        if (!s.isEmpty() && FORMULA_PREFIXES.indexOf(s.charAt(0)) >= 0) {
            s = "'" + s;
        }
        boolean quote = s.indexOf(',') >= 0 || s.indexOf('"') >= 0 || s.indexOf('\n') >= 0 || s.indexOf('\r') >= 0
                || s.indexOf(';') >= 0 || s.indexOf('\t') >= 0 || s.startsWith("'");
        return quote ? "\"" + s.replace("\"", "\"\"") + "\"" : s;
    }

    /** Bir satir (sonunda CRLF). */
    public static String row(List<?> cells) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < cells.size(); i++) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append(cell(cells.get(i)));
        }
        return sb.append("\r\n").toString();
    }
}
