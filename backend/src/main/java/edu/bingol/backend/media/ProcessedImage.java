package edu.bingol.backend.media;

/** {@link ImageProcessor} ciktisi: yeniden kodlanmis (metaverisiz) ana gorsel + kucuk resim baytlari. */
public record ProcessedImage(byte[] data, byte[] thumb, int width, int height, String contentType, String ext,
                             int thumbEdge) {

    /** `thumbEdge`: kucuk resmin GERCEK uzun kenari (px); istemci bu degerle balonda yeterli mi karar verir. */
    public ProcessedImage(byte[] data, byte[] thumb, int width, int height, String contentType, String ext) {
        this(data, thumb, width, height, contentType, ext, 0);
    }
}
