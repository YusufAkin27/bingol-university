package edu.bingol.backend.academician;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import org.junit.jupiter.api.Test;

/** Duyuru dosyasi dogrulamasi: uzanti + icerik imzasi, makro/calistirilabilir/html reddi, ad temizligi. Dosyalar kodda uretilir. */
class NoticeFileSnifferTest {

    static byte[] pdf() {
        return "%PDF-1.4\n1 0 obj\n<<>>\nendobj\n%%EOF".getBytes(StandardCharsets.US_ASCII);
    }

    static byte[] png() {
        return new byte[] {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0};
    }

    static byte[] jpg() {
        return new byte[] {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0, 0x10, 'J', 'F', 'I', 'F'};
    }

    /** OLE bilesik dosya imzasi + UTF-16LE akis adi. */
    static byte[] ole(String stream) {
        byte[] sig = {(byte) 0xD0, (byte) 0xCF, 0x11, (byte) 0xE0, (byte) 0xA1, (byte) 0xB1, 0x1A, (byte) 0xE1};
        byte[] name = stream.getBytes(StandardCharsets.UTF_16LE);
        byte[] out = new byte[sig.length + 64 + name.length];
        System.arraycopy(sig, 0, out, 0, sig.length);
        System.arraycopy(name, 0, out, sig.length + 64, name.length);
        return out;
    }

    static byte[] ooxml(String rootDir, String contentTypes, String... extraEntries) throws IOException {
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        try (ZipOutputStream z = new ZipOutputStream(bos)) {
            put(z, "[Content_Types].xml", contentTypes);
            put(z, rootDir + "document.xml", "<x/>");
            for (String e : extraEntries) {
                put(z, e, "x");
            }
        }
        return bos.toByteArray();
    }

    private static void put(ZipOutputStream z, String name, String body) throws IOException {
        z.putNextEntry(new ZipEntry(name));
        z.write(body.getBytes(StandardCharsets.UTF_8));
        z.closeEntry();
    }

    private static final String CT = "<Types><Override ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>";
    private static final String CT_MACRO = "<Types><Override ContentType=\"application/vnd.ms-word.document.macroEnabled.main+xml\"/></Types>";

    private static void ok(String name, byte[] data, String type) {
        var d = NoticeFileSniffer.detect(name, data);
        assertTrue(d.isPresent(), name);
        assertEquals(type, d.get().contentType(), name);
    }

    private static void bad(String name, byte[] data) {
        assertFalse(NoticeFileSniffer.detect(name, data).isPresent(), name);
    }

    @Test
    void everyAllowedTypeIsAcceptedWithServerDeterminedContentType() throws IOException {
        ok("a.pdf", pdf(), "application/pdf");
        ok("a.png", png(), "image/png");
        ok("a.jpg", jpg(), "image/jpeg");
        ok("a.JPEG", jpg(), "image/jpeg");
        ok("a.txt", "Merhaba dünya\nsatır 2\n".getBytes(StandardCharsets.UTF_8), "text/plain; charset=UTF-8");
        ok("a.doc", ole("WordDocument"), "application/msword");
        ok("a.xls", ole("Workbook"), "application/vnd.ms-excel");
        ok("a.xls", ole("Book"), "application/vnd.ms-excel");
        ok("a.ppt", ole("PowerPoint Document"), "application/vnd.ms-powerpoint");
        ok("a.docx", ooxml("word/", CT), "application/vnd.openxmlformats-officedocument.wordprocessingml.document");
        ok("a.xlsx", ooxml("xl/", CT), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        ok("a.pptx", ooxml("ppt/", CT), "application/vnd.openxmlformats-officedocument.presentationml.presentation");
    }

    @Test
    void renamedExecutableIsRejected() {
        byte[] exe = new byte[] {'M', 'Z', (byte) 0x90, 0, 3, 0, 0, 0, 4, 0, 0, 0};
        bad("evil.pdf", exe);
        bad("evil.png", exe);
        bad("evil.txt", exe); // NUL baytlari
        bad("evil.exe", exe);
        bad("evil.docx", exe);
        byte[] elf = new byte[] {0x7F, 'E', 'L', 'F', 2, 1, 1, 0};
        bad("evil.jpg", elf);
        bad("evil.txt", elf);
    }

    @Test
    void extensionMustMatchContent() throws IOException {
        bad("a.pdf", png());
        bad("a.png", pdf());
        bad("a.doc", ole("Workbook"));
        bad("a.xls", ole("WordDocument"));
        bad("a.docx", ooxml("xl/", CT)); // xlsx icerigi docx adiyla
        bad("a.docx", ole("WordDocument"));
        bad("a.doc", pdf());
    }

    @Test
    void macroEnabledAndEmbeddedBinariesAreRejected() throws IOException {
        bad("a.docm", ooxml("word/", CT_MACRO));
        bad("a.xlsm", ooxml("xl/", CT));
        bad("a.pptm", ooxml("ppt/", CT));
        // docx adli ama makro icerik turu / vbaProject iceriyor
        bad("a.docx", ooxml("word/", CT_MACRO));
        bad("a.docx", ooxml("word/", CT, "word/vbaProject.bin"));
    }

    @Test
    void htmlSvgScriptsAndArchivesAreRejected() {
        bad("a.html", "<html><script>alert(1)</script></html>".getBytes(StandardCharsets.UTF_8));
        bad("a.svg", "<svg xmlns=\"http://www.w3.org/2000/svg\"/>".getBytes(StandardCharsets.UTF_8));
        bad("a.txt", "<!DOCTYPE html><html></html>".getBytes(StandardCharsets.UTF_8));
        bad("a.txt", "  <svg onload=alert(1)>".getBytes(StandardCharsets.UTF_8));
        bad("a.txt", "#!/bin/sh\nrm -rf /\n".getBytes(StandardCharsets.UTF_8));
        bad("a.sh", "echo hi".getBytes(StandardCharsets.UTF_8));
        bad("a.js", "alert(1)".getBytes(StandardCharsets.UTF_8));
        bad("a.zip", new byte[] {'P', 'K', 3, 4, 0, 0});
        bad("a.rar", new byte[] {'R', 'a', 'r', '!', 0x1A, 7, 0});
        bad("a.7z", new byte[] {'7', 'z', (byte) 0xBC, (byte) 0xAF, 0x27, 0x1C});
        bad("a.gif", "GIF89a....".getBytes(StandardCharsets.US_ASCII));
        bad("noext", pdf());
        bad("a.pdf", new byte[0]);
    }

    @Test
    void brokenZipContainerIsRejected() {
        byte[] notReallyZip = new byte[] {'P', 'K', 3, 4, 1, 2, 3, 4, 5, 6, 7, 8};
        bad("a.docx", notReallyZip);
    }

    @Test
    void filenamesAreSanitised() {
        assertEquals("passwd.pdf", NoticeFileSniffer.sanitizeName("../../etc/passwd.pdf"));
        assertEquals("evil.pdf", NoticeFileSniffer.sanitizeName("C:\\Windows\\evil.pdf"));
        assertEquals("a b.pdf", NoticeFileSniffer.sanitizeName("a\r\nb.pdf".replace("\r\n", " ")));
        assertEquals("ab.pdf", NoticeFileSniffer.sanitizeName("a\u0000\u0007b.pdf"));
        assertEquals("fdp.exe", NoticeFileSniffer.sanitizeName("\u202Eexe.pdf".replace("exe.pdf", "fdp.exe")));
        assertEquals("x.pdf", NoticeFileSniffer.sanitizeName("\"x\";<>|?*.pdf"));
        assertEquals("hidden.txt", NoticeFileSniffer.sanitizeName("...hidden.txt"));
        assertEquals("dosya", NoticeFileSniffer.sanitizeName("   "));
        assertEquals("dosya", NoticeFileSniffer.sanitizeName(null));
        String longName = "a".repeat(500) + ".pdf";
        String s = NoticeFileSniffer.sanitizeName(longName);
        assertTrue(s.length() <= 200, "uzunluk");
        assertTrue(s.endsWith(".pdf"), "uzanti korunur");
        for (String n : Map.of("a", NoticeFileSniffer.sanitizeName("x/../..\\y\n.pdf")).values()) {
            assertFalse(n.contains("/") || n.contains("\\") || n.contains(".."), n);
        }
    }
}
