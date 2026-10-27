package edu.bingol.backend.common;

import org.springframework.http.HttpStatus;

/** Belirli bir istek alanina bagli is kurali hatasi: govde `{code,message,field}` olur. */
public class FieldApiException extends ApiException {

    private final String field;

    public FieldApiException(HttpStatus status, String code, String message, String field) {
        super(status, code, message);
        this.field = field;
    }

    public String field() {
        return field;
    }
}
