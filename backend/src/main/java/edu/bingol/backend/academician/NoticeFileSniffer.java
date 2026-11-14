package edu.bingol.backend.academician;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Enumeration;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/**
 * Duyuru dosyasi dogrulamasi (saf, birim testli). Hem UZANTI beyaz listede olmali hem ICERIK imzasi uzantiyla eslesmeli;
 * tur ISTEMCININ bildirdigi degil sunucunun belirledigi turdur. Makro destekli bicimler (docm/xlsm/pptm), calistirilabilir,
 * betik, arsiv, html/svg ve imzasi uzantiyla uyusmayan her sey reddedilir.
 * <ul>
 *   <li>pdf: "%PDF-" ilk 1024 baytta; png/jpg: sihirli baytlar;</li>
 *   <li>docx/xlsx/pptx: ZIP kabi; [Content_Types].xml var, bicime ozgu kok dizin (word/, xl/, ppt/) var, makro (vbaProject.bin,
 *       macroEnabled icerik turu) yok; yalniz merkezi dizin ve [Content_Types].xml okunur (zip bombasi yok);</li>
 *   <li>doc/xls/ppt: OLE bileşik dosya imzasi + bicime ozgu akis adi (WordDocument / Workbook|Book / PowerPoint Document);</li>
 *   <li>txt: ikili/kontrol baytlari yok, calistirilabilir/html/betik basligi yok.</li>
 * </ul>
 * Bilinen sinir: eski OLE (doc/xls/ppt) icindeki makro (VBA) burada sezilmez; dosya yalniz indirilir, sunucuda calistirilmaz.
 */
public final class NoticeFileSniffer {

    /** Sunucunun belirledigi tur. */
    public record Detected(String ext, String contentType) {}

    private static final Map<String, String> TYPES = Map.ofEntries(
            Map.entry("pdf", "application/pdf"),
            Map.entry("doc", "application/msword"),
            Map.entry("docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
            Map.entry("ppt", "application/vnd.ms-powerpoint"),
            Map.entry("pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation"),
            Map.entry("xls", "application/vnd.ms-excel"),
            Map.entry("xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
            Map.entry("txt", "text/plain; charset=UTF-8"),
            Map.entry("png", "image/png"),
            Map.entry("jpg", "image/jpeg"),
            Map.entry("jpeg", "image/jpeg"));
    private static final byte[] OLE = {(byte) 0xD0, (byte) 0xCF, 0x11, (byte) 0xE0, (byte) 0xA1, (byte) 0xB1, 0x1A, (byte) 0xE1};
    private static final byte[] PNG = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};
    private static final int MAX_ZIP_ENTRIES = 5000;
    private static final int MAX_CONTENT_TYPES_BYTES = 1 << 20;

    private NoticeFileSniffer() {}

    public static Set<String> allowedExtensions() {
        return TYPES.keySet();
    }

    /** Son uzanti (kucuk harf); yoksa bos. Yol/kontrol karakterleri temizlendikten SONRA cagrilmalidir. */
    public static String extensionOf(String name) {
        if (name == null) {
            return "";
        }
        int dot = name.lastIndexOf('.');
        return dot < 0 || dot == name.length() - 1 ? "" : name.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    /** Gecerliyse sunucu turunu dondurur; degilse bos (cagiran 422 NOTICE_FILE_TYPE_NOT_ALLOWED verir). */
    public static Optional<Detected> detect(String sanitizedName, byte[] data) {
        String ext = extensionOf(sanitizedName);
        String type = TYPES.get(ext);
        if (type == null || data == null || data.length < 4) {
            return Optional.empty();
        }
        boolean ok = switch (ext) {
            case "pdf" -> pdf(data);
            case "png" -> startsWith(data, PNG);
            case "jpg", "jpeg" -> data.length > 3 && (data[0] & 0xFF) == 0xFF && (data[1] & 0xFF) == 0xD8 && (data[2] & 0xFF) == 0xFF;
            case "docx" -> ooxml(data, "word/");
            case "xlsx" -> ooxml(data, "xl/");
            case "pptx" -> ooxml(data, "ppt/");
            case "doc" -> ole(data, "WordDocument");
            case "xls" -> ole(data, "Workbook") || ole(data, "Book");
            case "ppt" -> ole(data, "PowerPoint Document");
            case "txt" -> text(data);
            default -> false;
        };
        return ok ? Optional.of(new Detected(ext, type)) : Optional.empty();
    }

    /**
     * Gosterilecek/saklanacak ad: yol ayiricilari ve kontrol/yonlendirme karakterleri atilir, kisaltilir, uzanti korunur.
     * Sonuc hicbir zaman bos degildir ve yol gezintisi (.., /, \) icermez.
     */
    public static String sanitizeName(String raw) {
        String s = raw == null ? "" : raw;
        int cut = Math.max(s.lastIndexOf('/'), s.lastIndexOf('\\'));
        if (cut >= 0) {
            s = s.substring(cut + 1);
        }
        StringBuilder b = new StringBuilder();
        s.codePoints().forEach(cp -> {
            boolean bad = cp < 0x20 || cp == 0x7F || (cp >= 0x80 && cp < 0xA0) || (cp >= 0x202A && cp <= 0x202E)
                    || (cp >= 0x2066 && cp <= 0x2069) || cp == 0x200E || cp == 0x200F || cp == 0xFEFF
                    || "\"<>:*?|;".indexOf(cp) >= 0;
            if (!bad) {
                b.appendCodePoint(cp);
            }
        });
        String out = b.toString().replaceAll("\\s+", " ").strip();
        while (out.startsWith(".")) {
            out = out.substring(1).strip();
        }
        String ext = extensionOf(out);
        if (out.isEmpty() || (ext.isEmpty() && !out.contains("."))) {
            return out.isEmpty() ? "dosya" : out;
        }
        if (out.length() > 200) {
            String keep = ext.isEmpty() ? "" : "." + ext;
            out = out.substring(0, 200 - keep.length()).strip() + keep;
        }
        return out;
    }

    // ---- bicim denetimleri ----

    private static boolean pdf(byte[] d) {
        byte[] sig = "%PDF-".getBytes(StandardCharsets.US_ASCII);
        int limit = Math.min(d.length - sig.length, 1024);
        for (int i = 0; i <= limit; i++) {
            if (regionEquals(d, i, sig)) {
                return true;
            }
        }
        return false;
    }

    private static boolean ole(byte[] d, String streamName) {
        if (!startsWith(d, OLE)) {
            return false;
        }
        byte[] needle = streamName.getBytes(StandardCharsets.UTF_16LE); // OLE dizin girdileri UTF-16LE adlidir
        for (int i = 0; i <= d.length - needle.length; i++) {
            if (d[i] == needle[0] && regionEquals(d, i, needle)) {
                return true;
            }
        }
        return false;
    }

    private static boolean ooxml(byte[] d, String rootDir) {
        if (!(d.length > 4 && d[0] == 'P' && d[1] == 'K' && d[2] == 3 && d[3] == 4)) {
            return false;
        }
        Path tmp = null;
        try {
            tmp = Files.createTempFile("ac-notice-", ".zip");
            Files.write(tmp, d);
            try (ZipFile zip = new ZipFile(tmp.toFile())) {
                boolean hasTypes = false;
                boolean hasRoot = false;
                int n = 0;
                Enumeration<? extends ZipEntry> en = zip.entries();
                while (en.hasMoreElements()) {
                    ZipEntry e = en.nextElement();
                    if (++n > MAX_ZIP_ENTRIES) {
                        return false;
                    }
                    String name = e.getName();
                    if (name.startsWith("/") || name.contains("..") || name.contains("\\")) {
                        return false;
                    }
                    String lower = name.toLowerCase(Locale.ROOT);
                    if (lower.endsWith("vbaproject.bin") || lower.endsWith(".exe") || lower.endsWith(".dll")) {
                        return false;
                    }
                    hasTypes |= name.equals("[Content_Types].xml");
                    hasRoot |= name.startsWith(rootDir);
                }
                if (!hasTypes || !hasRoot) {
                    return false;
                }
                try (InputStream in = zip.getInputStream(zip.getEntry("[Content_Types].xml"))) {
                    byte[] ct = in.readNBytes(MAX_CONTENT_TYPES_BYTES + 1);
                    if (ct.length > MAX_CONTENT_TYPES_BYTES) {
                        return false;
                    }
                    String xml = new String(ct, StandardCharsets.UTF_8).toLowerCase(Locale.ROOT);
                    return !xml.contains("macroenabled") && !xml.contains("vbaproject");
                }
            }
        } catch (IOException | RuntimeException e) {
            return false;
        } finally {
            if (tmp != null) {
                try {
                    Files.deleteIfExists(tmp);
                } catch (IOException ignored) {
                    // gecici dosya; sistem temizler
                }
            }
        }
    }

    private static boolean text(byte[] d) {
        int n = Math.min(d.length, 1 << 16);
        for (int i = 0; i < n; i++) {
            int b = d[i] & 0xFF;
            if (b == 0 || (b < 0x20 && b != '\t' && b != '\n' && b != '\r' && b != '\f') || b == 0x7F) {
                return false;
            }
        }
        String head = new String(d, 0, Math.min(d.length, 2048), StandardCharsets.UTF_8).toLowerCase(Locale.ROOT).stripLeading();
        for (String bad : new String[] {"<!doctype", "<html", "<script", "<svg", "<?xml", "#!", "%pdf"}) {
            if (head.startsWith(bad)) {
                return false;
            }
        }
        return !head.contains("<script") && !head.contains("<html") && !head.contains("<svg");
    }

    private static boolean startsWith(byte[] d, byte[] sig) {
        return d.length >= sig.length && Arrays.equals(Arrays.copyOf(d, sig.length), sig);
    }

    private static boolean regionEquals(byte[] d, int off, byte[] sig) {
        if (off + sig.length > d.length) {
            return false;
        }
        for (int i = 0; i < sig.length; i++) {
            if (d[off + i] != sig[i]) {
                return false;
            }
        }
        return true;
    }
}
