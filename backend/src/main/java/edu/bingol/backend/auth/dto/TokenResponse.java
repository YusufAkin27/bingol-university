package edu.bingol.backend.auth.dto;

public record TokenResponse(String accessToken, String refreshToken, long expiresInSeconds, String tokenType) {
}
