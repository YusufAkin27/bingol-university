package edu.bingol.backend.common;

import jakarta.servlet.RequestDispatcher;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.boot.webmvc.error.ErrorController;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Konteyner hata yonlendirmesi (/error): filtre zincirinden gelen {@code sendError} (guvenlik 403'u, Tomcat 404/400,
 * filtrede yakalanmayan istisna) HER ZAMAN standart {@code {code,message,traceId}} JSON'u olur. Spring Boot'un
 * varsayilan BasicErrorController'i (HTML "Whitelabel"/Tomcat sayfasi, kodsuz JSON) bu bean yuzunden devre disi kalir
 * (T-004).
 */
@RestController
public class ApiErrorController implements ErrorController {

    private final ApiErrorWriter writer;

    public ApiErrorController(ApiErrorWriter writer) {
        this.writer = writer;
    }

    @RequestMapping("${server.error.path:/error}")
    public void error(HttpServletRequest request, HttpServletResponse response) throws IOException {
        Object attr = request.getAttribute(RequestDispatcher.ERROR_STATUS_CODE);
        int status = attr instanceof Integer i && i >= 400 && i <= 599 ? i : 500;
        writer.write(request, response, status);
    }
}
