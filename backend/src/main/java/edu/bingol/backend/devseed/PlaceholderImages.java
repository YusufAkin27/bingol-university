package edu.bingol.backend.devseed;

import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import javax.imageio.ImageIO;

/** Tohum için küçük yer tutucu PNG üretir (FileStorage kökü altında `devseed/` klasörü). */
final class PlaceholderImages {

    private PlaceholderImages() {
    }

    /** @return herkese açık URL (`/files/devseed/<ad>.png`); dosya varsa yeniden yazılmaz. */
    static String ensure(Path storageRoot, String name, String label, int hue, int w, int h) throws IOException {
        Path dir = storageRoot.resolve("devseed");
        Files.createDirectories(dir);
        Path file = dir.resolve(name + ".png");
        if (!Files.isRegularFile(file)) {
            Files.write(file, png(label, hue, w, h));
        }
        return "/files/devseed/" + name + ".png";
    }

    static byte[] png(String label, int hue, int w, int h) throws IOException {
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = img.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g.setColor(Color.getHSBColor((hue % 360) / 360f, 0.45f, 0.85f));
        g.fillRect(0, 0, w, h);
        g.setColor(Color.getHSBColor((hue % 360) / 360f, 0.55f, 0.55f));
        g.fillOval(w / 2, -h / 3, w, h);
        g.setColor(Color.WHITE);
        g.setFont(new Font(Font.SANS_SERIF, Font.BOLD, Math.max(14, h / 8)));
        g.drawString(label, 16, h / 2);
        g.dispose();
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(img, "png", out);
        return out.toByteArray();
    }
}
