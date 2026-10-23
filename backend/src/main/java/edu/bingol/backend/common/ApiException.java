package edu.bingol.backend.common;

import org.springframework.http.HttpStatus;

/**
 * Is kurali hatasi. `code` istemci icin sabit makine kodudur; kullaniciya gosterilen metin
 * `error.<code>` anahtariyla istek dilinde cevrilir, anahtar yoksa `message` (Turkce) kullanilir.
 * `args` mesajdaki {0}, {1} yer tutuculari icindir (metin olarak verin).
 */
public class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final String code;
    private final transient Object[] args;

    public ApiException(HttpStatus status, String code, String message) {
        this(status, code, message, new Object[0]);
    }

    public ApiException(HttpStatus status, String code, String message, Object... args) {
        super(message);
        this.status = status;
        this.code = code;
        this.args = args;
    }

    public HttpStatus status() {
        return status;
    }

    public String code() {
        return code;
    }

    public Object[] args() {
        return args;
    }
}
