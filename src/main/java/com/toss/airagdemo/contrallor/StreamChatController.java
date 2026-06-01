package com.toss.airagdemo.contrallor;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.codec.ServerSentEvent;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Flux;

import java.time.Duration;

@RestController
@RequestMapping("/stream")
@CrossOrigin(originPatterns = "*", allowCredentials = "true")
public class StreamChatController {

    private final ChatClient chatClient;

    public StreamChatController(ChatClient.Builder chatClientBuilder) {
        this.chatClient = chatClientBuilder.build();
    }

    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("ok");
    }

    @GetMapping("/clear")
    public ResponseEntity<String> clear() {
        return ResponseEntity.ok("ok");
    }

    @GetMapping(value = "/chat", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<ServerSentEvent<String>> streamChat(@RequestParam String message) {
        if (message == null || message.trim().isEmpty()) {
            return Flux.just(event("ai-error", "消息不能为空"));
        }

        Flux<String> rawStream = chatClient.prompt()
                .user(message.trim())
                .stream()
                .content();

        return rawStream
                .filter(content -> content != null && !content.isEmpty())
                .map(content -> event("message", content))
                .timeout(Duration.ofSeconds(180))
                .concatWithValues(event("done", "[DONE]"))
                .onErrorResume(ex -> Flux.just(event("ai-error", "AI 服务暂时不可用：" + ex.getMessage())));
    }

    private ServerSentEvent<String> event(String name, String data) {
        return ServerSentEvent.builder(data).event(name).build();
    }
}
