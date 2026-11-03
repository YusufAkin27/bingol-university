package edu.bingol.backend.academic;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamConstants;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamReader;

/**
 * Bagimliliksiz minimal .xlsx okuyucu (yalniz hucre METNI: biçim/formul sonucu/grafik yok). Yonetici yuklemesi icin:
 * zip-bombasina karsi boyut ve satir sinirlari vardir; XML okuyucuda DTD ve dis varliklar kapalidir (XXE).
 */
final class XlsxReader {

    static final int MAX_ROWS = 20_000;
    static final int MAX_COLS = 60;
    private static final long MAX_ENTRY_BYTES = 24L * 1024 * 1024;
    private static final long MAX_TOTAL_BYTES = 64L * 1024 * 1024;

    /** Gecersiz/bozuk dosya: mesaj yoneticiye gosterilebilir (Turkce). */
    static final class XlsxException extends RuntimeException {
        XlsxException(String m, Throwable cause) {
            super(m, cause);
        }
    }

    private XlsxReader() {}

    /**
     * @param sheetName tercih edilen sayfa adi (buyuk/kucuk harf duyarsiz); yoksa ilk sayfa
     * @return satirlar; her satir en cok MAX_COLS hucre, bos hucre ""; ham deger (sayilar olduğu gibi, ör. "0.34375")
     */
    static List<List<String>> read(InputStream in, String sheetName) {
        try {
            Map<String, byte[]> parts = unzip(in);
            byte[] wb = parts.get("xl/workbook.xml");
            if (wb == null) {
                throw new XlsxException("Geçerli bir .xlsx dosyası değil (xl/workbook.xml yok).", null);
            }
            List<String[]> sheets = sheets(wb); // {ad, rId}
            if (sheets.isEmpty()) {
                throw new XlsxException("Çalışma kitabında sayfa yok.", null);
            }
            String rid = sheets.get(0)[1];
            if (sheetName != null) {
                for (String[] s : sheets) {
                    if (s[0].trim().equalsIgnoreCase(sheetName.trim())) {
                        rid = s[1];
                        break;
                    }
                }
            }
            String target = rels(parts.get("xl/_rels/workbook.xml.rels")).get(rid);
            if (target == null) {
                throw new XlsxException("Sayfa dosyası bulunamadı.", null);
            }
            String path = target.startsWith("/") ? target.substring(1) : "xl/" + target;
            byte[] sheet = parts.get(path);
            if (sheet == null) {
                throw new XlsxException("Sayfa verisi okunamadı: " + path, null);
            }
            List<String> shared = parts.containsKey("xl/sharedStrings.xml") ? sharedStrings(parts.get("xl/sharedStrings.xml")) : List.of();
            return rows(sheet, shared);
        } catch (XMLStreamException | IOException e) {
            throw new XlsxException("Excel dosyası okunamadı: " + e.getMessage(), e);
        }
    }

    private static Map<String, byte[]> unzip(InputStream in) throws IOException {
        Map<String, byte[]> out = new HashMap<>();
        long total = 0;
        try (ZipInputStream zin = new ZipInputStream(in, StandardCharsets.UTF_8)) {
            ZipEntry e;
            while ((e = zin.getNextEntry()) != null) {
                String n = e.getName();
                if (e.isDirectory() || !(n.equals("xl/workbook.xml") || n.equals("xl/_rels/workbook.xml.rels")
                        || n.equals("xl/sharedStrings.xml") || n.startsWith("xl/worksheets/") && n.endsWith(".xml"))) {
                    continue;
                }
                java.io.ByteArrayOutputStream bos = new java.io.ByteArrayOutputStream();
                byte[] buf = new byte[16 * 1024];
                int r;
                long size = 0;
                while ((r = zin.read(buf)) > 0) {
                    size += r;
                    total += r;
                    if (size > MAX_ENTRY_BYTES || total > MAX_TOTAL_BYTES) {
                        throw new XlsxException("Excel dosyası çok büyük.", null);
                    }
                    bos.write(buf, 0, r);
                }
                out.put(n, bos.toByteArray());
            }
        }
        return out;
    }

    private static XMLStreamReader xml(byte[] b) throws XMLStreamException {
        XMLInputFactory f = XMLInputFactory.newFactory();
        f.setProperty(XMLInputFactory.SUPPORT_DTD, false);
        f.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false);
        return f.createXMLStreamReader(new ByteArrayInputStream(b));
    }

    private static List<String[]> sheets(byte[] wb) throws XMLStreamException {
        List<String[]> out = new ArrayList<>();
        XMLStreamReader r = xml(wb);
        while (r.hasNext()) {
            if (r.next() == XMLStreamConstants.START_ELEMENT && r.getLocalName().equals("sheet")) {
                String id = null;
                for (int i = 0; i < r.getAttributeCount(); i++) {
                    if (r.getAttributeLocalName(i).equals("id")) {
                        id = r.getAttributeValue(i);
                    }
                }
                out.add(new String[] {r.getAttributeValue(null, "name"), id});
            }
        }
        return out;
    }

    private static Map<String, String> rels(byte[] b) throws XMLStreamException {
        Map<String, String> out = new HashMap<>();
        if (b == null) {
            return out;
        }
        XMLStreamReader r = xml(b);
        while (r.hasNext()) {
            if (r.next() == XMLStreamConstants.START_ELEMENT && r.getLocalName().equals("Relationship")) {
                out.put(r.getAttributeValue(null, "Id"), r.getAttributeValue(null, "Target"));
            }
        }
        return out;
    }

    private static List<String> sharedStrings(byte[] b) throws XMLStreamException {
        List<String> out = new ArrayList<>();
        XMLStreamReader r = xml(b);
        StringBuilder cur = null;
        boolean inT = false;
        int phonetic = 0;
        while (r.hasNext()) {
            int ev = r.next();
            if (ev == XMLStreamConstants.START_ELEMENT) {
                String n = r.getLocalName();
                if (n.equals("si")) {
                    cur = new StringBuilder();
                } else if (n.equals("rPh")) {
                    phonetic++;
                } else if (n.equals("t") && cur != null && phonetic == 0) {
                    inT = true;
                }
            } else if (ev == XMLStreamConstants.CHARACTERS && inT) {
                cur.append(r.getText());
            } else if (ev == XMLStreamConstants.END_ELEMENT) {
                String n = r.getLocalName();
                if (n.equals("t")) {
                    inT = false;
                } else if (n.equals("rPh")) {
                    phonetic--;
                } else if (n.equals("si") && cur != null) {
                    out.add(cur.toString());
                    cur = null;
                }
            }
        }
        return out;
    }

    private static List<List<String>> rows(byte[] sheet, List<String> shared) throws XMLStreamException {
        List<List<String>> out = new ArrayList<>();
        XMLStreamReader r = xml(sheet);
        List<String> row = null;
        String type = null;
        int col = 0;
        StringBuilder val = null;
        boolean inV = false;
        boolean inT = false;
        int rowNo = 0;
        while (r.hasNext()) {
            int ev = r.next();
            if (ev == XMLStreamConstants.START_ELEMENT) {
                switch (r.getLocalName()) {
                    case "row" -> {
                        String rn = r.getAttributeValue(null, "r");
                        int target = rn == null ? rowNo + 1 : Integer.parseInt(rn);
                        if (target > MAX_ROWS) {
                            throw new XlsxException("Sayfada en fazla " + MAX_ROWS + " satır olabilir.", null);
                        }
                        while (out.size() < target - 1) {
                            out.add(List.of());
                        }
                        row = new ArrayList<>();
                        rowNo = target;
                    }
                    case "c" -> {
                        type = r.getAttributeValue(null, "t");
                        col = colIndex(r.getAttributeValue(null, "r"), row == null ? 0 : row.size());
                        val = new StringBuilder();
                    }
                    case "v" -> inV = true;
                    case "t" -> inT = val != null; // inlineStr
                    default -> { }
                }
            } else if (ev == XMLStreamConstants.CHARACTERS) {
                if ((inV || inT) && val != null) {
                    val.append(r.getText());
                }
            } else if (ev == XMLStreamConstants.END_ELEMENT) {
                switch (r.getLocalName()) {
                    case "v" -> inV = false;
                    case "t" -> inT = false;
                    case "c" -> {
                        if (row != null && val != null && col < MAX_COLS) {
                            String s = val.toString();
                            if ("s".equals(type)) {
                                try {
                                    int i = Integer.parseInt(s.trim());
                                    s = i >= 0 && i < shared.size() ? shared.get(i) : "";
                                } catch (NumberFormatException e) {
                                    s = "";
                                }
                            }
                            while (row.size() < col) {
                                row.add("");
                            }
                            if (row.size() == col) {
                                row.add(s);
                            } else {
                                row.set(col, s);
                            }
                        }
                        val = null;
                    }
                    case "row" -> {
                        if (row != null) {
                            out.add(row);
                        }
                        row = null;
                    }
                    default -> { }
                }
            }
        }
        return out;
    }

    /** "B12" -> 1; ref yoksa sirayla (fallback). */
    private static int colIndex(String ref, int fallback) {
        if (ref == null) {
            return fallback;
        }
        int n = 0;
        for (int i = 0; i < ref.length(); i++) {
            char c = ref.charAt(i);
            if (c >= 'A' && c <= 'Z') {
                n = n * 26 + (c - 'A' + 1);
            } else {
                break;
            }
        }
        return Math.max(n - 1, 0);
    }
}
