package edu.bingol.backend.media;

/** {@link ImageProcessor} ciktisi: yeniden kodlanmis (metaverisiz) ana gorsel + kucuk resim baytlari. */
public record ProcessedImage(byte[] data, byte[] thumb, int width, int height, String contentType, String ext) {
}
