package edu.bingol.backend.notification.fcm;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;

import com.google.api.client.http.ByteArrayContent;
import com.google.api.client.http.GenericUrl;
import com.google.api.client.http.HttpRequest;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.sun.net.httpserver.HttpServer;
import java.io.ByteArrayOutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.zip.GZIPOutputStream;
import org.junit.jupiter.api.Test;

/**
 * FCM sunucusu yaniti gzip'li gonderir. Varsayilan firebase-admin aktarimi (ApacheHttp2Transport) Spring Boot BOM'undaki
 * httpclient5 ile gzip'i iki kez acip "ZipException: Not in GZIP format" verdi; FirebaseFcmSender JDK aktarimini sabitler.
 * Bu test o secimin gzip'li yaniti dogru okudugunu kilitler (sahte yerel sunucu, ag/kimlik bilgisi gerekmez).
 */
class FcmTransportGzipTest {

    private static final String JSON = "{\"name\":\"projects/x/messages/1\"}";

    @Test
    void senderUsesJdkTransport() {
        assertInstanceOf(NetHttpTransport.class, FirebaseFcmSender.transport());
    }

    @Test
    void gzipResponseIsReadOnce() throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", ex -> {
            ex.getRequestBody().readAllBytes();
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            try (GZIPOutputStream gz = new GZIPOutputStream(bos)) {
                gz.write(JSON.getBytes(StandardCharsets.UTF_8));
            }
            byte[] body = bos.toByteArray();
            ex.getResponseHeaders().add("Content-Type", "application/json; charset=UTF-8");
            ex.getResponseHeaders().add("Content-Encoding", "gzip");
            ex.sendResponseHeaders(200, body.length);
            ex.getResponseBody().write(body);
            ex.close();
        });
        server.start();
        try {
            String url = "http://127.0.0.1:" + server.getAddress().getPort() + "/v1/projects/x/messages:send";
            HttpRequest req = FirebaseFcmSender.transport().createRequestFactory().buildPostRequest(new GenericUrl(url),
                    ByteArrayContent.fromString("application/json", "{}"));
            assertEquals(JSON, req.execute().parseAsString());
        } finally {
            server.stop(0);
        }
    }
}
