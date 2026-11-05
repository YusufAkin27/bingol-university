package edu.bingol.backend.common;

import java.util.Map;

/**
 * {@link ApiException} alt sinifi bunu uygularsa hata govdesine ({code,message,traceId}) ek ALANLAR yazilir
 * (ornek: OAUTH_LINK_REQUIRED {provider, emailMasked}). Degerler duz metin olmali; kisisel veri maskelenmis verilir.
 */
public interface ExtraBody {

    Map<String, String> extraBody();
}
