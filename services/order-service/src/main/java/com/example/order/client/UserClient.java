package com.example.order.client;

import com.example.order.dto.UserResponse;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
public class UserClient {
    private final RestClient client;
    public UserClient(RestClient.Builder builder, @Value("${clients.user-service.url}") String baseUrl) {
        this.client = builder.baseUrl(baseUrl).build();
    }

    @Retry(name = "userService")
    @CircuitBreaker(name = "userService")
    public UserResponse getUser(Long id) {
        return client.get().uri("/api/v1/users/{id}", id).retrieve().body(UserResponse.class);
    }
}
