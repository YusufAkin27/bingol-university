package edu.bingol.backend.messaging;

import edu.bingol.backend.export.DataExporter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.domain.PageRequest;

/** KVKK "verilerimi indir": kullanicinin kendi gonderdigi mesajlar, sifresi cozulmus olarak (en yeni 5000). */
@Configuration
public class MessageExporters {

    static final int MAX_EXPORT = 5000;

    @Bean
    DataExporter messageExporter(MessageRepository messages, MessageCodec codec) {
        return DataExporter.of("sentMessages", uid -> {
            List<Message> rows = codec.openAll(messages.sentBy(uid, PageRequest.of(0, MAX_EXPORT)));
            List<Map<String, Object>> out = rows.stream().map(m -> {
                Map<String, Object> e = new LinkedHashMap<>();
                e.put("id", m.getId());
                e.put("conversationId", m.getConversationId());
                e.put("createdAt", m.getCreatedAt().toString());
                e.put("removed", m.isHidden());
                e.put("text", m.isHidden() ? null : m.getBody());
                return e;
            }).toList();
            return Map.of("count", out.size(), "truncated", out.size() >= MAX_EXPORT, "messages", out);
        });
    }
}
